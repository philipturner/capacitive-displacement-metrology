#include "Application.h"

#include "Diagnostics/Log.h"
#include "IC/DAC.h"
#include "IC/PA95.h"

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
  PA95::writeVoltage(channelID, voltage);

  float dV = voltage - previousVoltage;
  state.addSpike(dV, C);
}

void Application::updateBiasVoltage(float voltage) {
  float dV = voltage - state.biasVoltage;
  float C = 50e-15;
  state.addSpike(dV, C);

  state.biasVoltage = voltage;
  DAC2::writeVoltage(0, voltage);
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
      /*flags=*/flags,
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
      /*flags=*/flags,
      currentMaximum,
      currentSpikePrediction,
      state.piezoZVoltage * 0.320,
      state.capacitance);
  } else if (mode == Command::Mode::tipApproach ||
             mode == Command::Mode::idleFeedback) {
    Log::writeValuesNormal(
      currentMaximum,
      currentSpikePrediction,
      state.piezoZVoltage * 0.320,
      state.positionError * 1e9,
      state.feedbackErrorTerm * 1e9);
  } else if (mode == Command::Mode::spectroscopy) {
    Log::writeValuesNormal(
      state.filteredCurrent,
      currentSpikePrediction,
      state.piezoZVoltage * 0.320,
      state.biasVoltage,
      state.positionError * 1e9);
  } else if (mode == Command::Mode::simpleScanning ||
             mode == Command::Mode::imaging) {
    // Metric that doesn't lose sensitivity as its magnitude grows larger.
    float2 drift = Application::creepFilter.futureAccumulatedDrift;
    float dV = drift.x + drift.y;
    
    Log::writeValuesNormal(
      abs(state.filteredCurrent * 1e12),
      state.piezoXVoltage * 0.320,
      state.piezoYVoltage * 0.320,
      state.piezoZVoltage * -0.320,
      dV * 0.320);
  }
}
