#include "Application.h"

#include "Command/Tilt/Settings.h"
#include "Diagnostics/Log.h"

uint32_t requiredCapacitanceUpdateCount() {
  if (Application::mode == Command::Mode::capacitanceReporting) {
    return 1;
  } else if (Application::mode == Command::Mode::blindStepping) {
    if (Application::blindStepper.mode == BlindStepper::Mode::capacitance) {
      auto state = Application::blindStepper.getCurrentState();
      if (state != BlindStepper::State::finished) {
        return 2;
      }
    }
  }
  return 0;
}

float2 getScannerVoltageForTilt() {
  if (Application::mode == Command::Mode::imaging) {
    return Application::imager.getUncorrectedVoltageXY();
  } else {
    return float2(
      Application::state.piezoXVoltage,
      Application::state.piezoYVoltage);
  }
}

// 0.227-0.280 us
// without current spike calculation: 0.077-0.132 us
void Application::logHistoryMessage() {
  float currentMaximum = state.extractCurrentMaximum();
  float currentSpikePrediction = 0;
  if (uint8_t(mode) < uint8_t(Command::Mode::simpleScanning)) {
    currentSpikePrediction = state.getPredictedCurrentSpike();
  }

  auto flags = Log::Flags::history;
  if (state.capacitanceUpdateCount < requiredCapacitanceUpdateCount()) {
    flags = Log::Flags::historyDiscard;
  }

  if (mode == Command::Mode::idle) {
    Log::write(flags,
      state.filteredCurrent,
      currentMaximum,
      currentSpikePrediction);
  } else if (mode == Command::Mode::dacTest) {
    Log::write(flags,
      state.filteredCurrent,
      currentMaximum,
      currentSpikePrediction,
      dacTester.getActiveChannelVoltage(),
      dacTester.channelID);
  } else if (mode == Command::Mode::capacitanceReporting) {
    Log::write(flags,
      state.filteredCurrent,
      state.biasVoltage,
      state.capacitance,
      state.phaseShift);
  } else if (mode == Command::Mode::blindStepping) {
    float fifthValue = 0;
    if (Application::blindStepper.mode == BlindStepper::Mode::capacitance) {
      float dx = 100e-9f;
      fifthValue = Application::state.dC_dstep / dx;
    }
    Log::write(flags,
      currentMaximum,
      currentSpikePrediction,
      state.piezoZVoltage * 0.320f,
      state.capacitance,
      fifthValue);
  } else if (mode == Command::Mode::tipApproach ||
             mode == Command::Mode::idleFeedback) {
    Log::write(flags,
      currentMaximum,
      currentSpikePrediction,
      state.piezoZVoltage * 0.320f);
  } else if (mode == Command::Mode::spectroscopy) {
    Log::write(flags,
      state.filteredCurrent,
      currentSpikePrediction,
      state.piezoZVoltage * 0.320f,
      state.biasVoltage,
      state.spectroscopyTrigger);
  } else if (mode == Command::Mode::simpleScanning ||
             mode == Command::Mode::imaging ||
             mode == Command::Mode::tiltCalculation) {
    float2 scannerVoltageForTilt = getScannerVoltageForTilt();
    float relativeZVoltage = Tilt::Settings::getRelativeZ(
      scannerVoltageForTilt.x,
      scannerVoltageForTilt.y,
      state.piezoZVoltage);
    
    // Metric that doesn't lose sensitivity as its magnitude grows larger.
    float2 drift = float(0);
    drift += Application::creepFilter.scaleError;
    drift += Application::creepFilter.futureAccumulatedDrift;
    drift += Application::creepFilter.earlyScaleError;
    float dV = drift.x + drift.y;
    
    Log::write(flags,
      Imager::transformCurrent(state.filteredCurrent),
      state.piezoXVoltage * 0.320f,
      state.piezoYVoltage * 0.320f,
      Imager::transformVoltageZ(relativeZVoltage) * 0.320f,
      dV * 0.320f);
  }
}
