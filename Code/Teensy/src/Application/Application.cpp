#include "Application.h"

#include "Command/Tilt/Settings.h"
#include "Diagnostics/Log.h"
#include "Filter/Feedback.h"
#include "IC/DAC.h"
#include "IC/PA95.h"

void Application::updateBiasVoltage(float voltage) {
  float dV = voltage - state.biasVoltage;
  float C = 50e-15;
  state.addSpike(dV, C);

  state.biasVoltage = voltage;
  DAC::enableSafeWait = false;
  DAC2::writeVoltage(0, voltage);
  DAC::enableSafeWait = true;
}

void Application::updatePiezoVoltage(uint32_t channelID, float voltage) {
  float C = 0;
  float previousVoltage = 0;
  if (channelID == 1) {
    C = 13e-18;
    previousVoltage = state.piezoXVoltage;
    state.piezoXVoltage = voltage;
  } else if (channelID == 2) {
    C = 45e-18;
    previousVoltage = state.piezoYVoltage;
    state.piezoYVoltage = voltage;
  } else if (channelID == 3) {
    C = 27e-18;
    previousVoltage = state.piezoZVoltage;
    state.piezoZVoltage = voltage;
  }
  if (channelID != 3) {
    PA95::writeVoltage(channelID, voltage);
  }

  float dV = voltage - previousVoltage;
  state.addSpike(dV, C);
}

void Application::updatePiezoZDeferred() {
  DAC::enableSafeWait = false;
  PA95::writeVoltage(3, state.piezoZVoltage);
  DAC::enableSafeWait = true;
}

void Application::updateCapacitanceTracker(bool regenerate) {
  // This only writes to capacitance and phaseShift if the mode is
  // transitioning from 'measuring' to 'finished'.
  capTracker.update();
  
  auto state = capTracker.getCurrentState();
  if (state == CapacitanceTracker::State::finished) {
    if (!regenerate) {
      return;
    }

    capTracker = CapacitanceTracker(true);
    capTracker.update();
  }

  float biasVoltage = capTracker.getBiasVoltage();
  Application::updateBiasVoltage(biasVoltage);

  float filteredCurrent = Application::state.filteredCurrent;
  capTracker.integrate(filteredCurrent);
}

void Application::logNormalMessage() {
  bool capacitanceDidChange = false;
  if (state.capacitanceUpdateCount > 0) {
    capacitanceDidChange = true;
  }

  float currentMaximum = state.extractCurrentMaximum();
  float currentSpikePrediction = state.getPredictedCurrentSpike();

  if (mode == Command::Mode::idle) {
    Log::writeValuesNormal(
      state.filteredCurrent,
      currentMaximum,
      currentSpikePrediction);
  } else if (mode == Command::Mode::dacTest) {
    Log::writeValuesNormal(
      state.filteredCurrent,
      currentMaximum,
      currentSpikePrediction,
      dacTester.getActiveChannelVoltage(),
      dacTester.channelID);
  } else if (mode == Command::Mode::capacitanceReporting) {
    uint8_t flags = 3;
    if (capacitanceDidChange) {
      flags = 0;
    }

    Log::writeValuesWithFlags(
      flags, // flags
      state.filteredCurrent,
      state.biasVoltage,
      state.capacitance,
      state.phaseShift);
  } else if (mode == Command::Mode::blindStepping) {
    uint8_t flags;
    if (blindStepper.mode == BlindStepper::Mode::capacitance) {
      flags = 3;
      if (capacitanceDidChange) {
        flags = 0;
      }
    } else {
      flags = 0;
    }

    Log::writeValuesWithFlags(
      flags, // flags
      currentMaximum,
      currentSpikePrediction,
      state.piezoZVoltage * 0.320f,
      state.capacitance);
  } else if (mode == Command::Mode::tipApproach ||
             mode == Command::Mode::idleFeedback) {
    Log::writeValuesNormal(
      currentMaximum,
      currentSpikePrediction,
      state.piezoZVoltage * 0.320f);
  } else if (mode == Command::Mode::spectroscopy) {
    Log::writeValuesNormal(
      state.filteredCurrent,
      currentSpikePrediction,
      state.piezoZVoltage * 0.320f,
      state.biasVoltage,
      state.spectroscopyTrigger);
  } else if (mode == Command::Mode::simpleScanning ||
             mode == Command::Mode::imaging ||
             mode == Command::Mode::tilt) {
    float2 voltageXY;
    if (mode == Command::Mode::imaging) {
      voltageXY = imager.getUncorrectedVoltageXY();
    } else {
      voltageXY.x = state.piezoXVoltage;
      voltageXY.y = state.piezoYVoltage;
    }
    
    float relativeZVoltage = Tilt::Settings::getRelativeZ(
      voltageXY.x,
      voltageXY.y,
      state.piezoZVoltage);
    
    // Metric that doesn't lose sensitivity as its magnitude grows larger.
    float2 drift = Application::creepFilter.futureAccumulatedDrift;
    float dV = drift.x + drift.y;
    
    Log::writeValuesNormal(
      Imager::transformCurrent(state.filteredCurrent),
      state.piezoXVoltage * 0.320f,
      state.piezoYVoltage * 0.320f,
      Imager::transformVoltageZ(relativeZVoltage) * 0.320f,
      dV * 0.320f);
  }
}

void Application::setBiasForFeedback() {
  updateBiasVoltage(Feedback::setpointVoltage);
}

void Application::correctZVoltage() {
  float2 dXY;
  dXY.x = state.piezoXVoltage - state.previous.x;
  dXY.y = state.piezoYVoltage - state.previous.y;
  correctZVoltage(dXY);
}

void Application::correctZVoltage(float2 dXY) {
  float newVoltageZ = state.piezoZVoltage;
  newVoltageZ += Feedback::getVoltageCorrection(state.current);
  newVoltageZ += Tilt::Settings::slope.x * dXY.x;
  newVoltageZ += Tilt::Settings::slope.y * dXY.y;

  newVoltageZ = min(newVoltageZ, 270);
  newVoltageZ = max(newVoltageZ, -80);
  updatePiezoVoltage(3, newVoltageZ);
}