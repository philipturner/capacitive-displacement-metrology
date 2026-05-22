#include "TipApproacher.h"

#include "Application/Application.h"
#include "Command/BlindStepper.h"
#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
#include "Util/FilterUtil.h"
#include <Arduino.h>

TipApproacher::TipApproacher() {

}

TipApproacher::TipApproacher(bool notDefaultConstructor) {
  float piezoZVoltage = Application::state.piezoZVoltage;
  if (piezoZVoltage != BlindStepper::restPosition) {
    // Ensure the characters for the voltage appear first if the PC's
    // serial plotter only scans the first ~20 characters.
    Serial.println(piezoZVoltage, 3);
    Serial.println("Tip approach did not start at expected position.");
    exit(0);
  }

  currentState = State::waiting;
  stateStartIterationID = KilohertzLoop::iterationID;
}

void TipApproacher::update() {
  updateState();
  updateDACs();
}

uint32_t TipApproacher::getTimeSinceStateStart() {
  uint32_t deltaIters = KilohertzLoop::iterationID;
  deltaIters -= stateStartIterationID;
  return deltaIters * KilohertzLoop::period;
}

void TipApproacher::updateState() {
  previousState = currentState;
  uint32_t previousTime = getTimeSinceStateStart();

  float current = Application::state.current;
  if (currentState != State::waiting) {
    if (abs(current) > setpointCurrent) {
      currentState = State::feedback;
    }
  }
  if (abs(current) > 5e-9) {
    feedback_diagnostic1 = 1;
  }

  if (currentState == State::waiting) {
    if (previousTime >= waitTime) {
      currentState = State::approaching;
    }
  } else if (currentState == State::approaching) {
    if (previousTime >= approachTime) {
      currentState = State::waiting;
    }
  }

  if (currentState != previousState) {
    stateStartIterationID = KilohertzLoop::iterationID;
  }
}

void TipApproacher::updateDACs() {
  uint32_t currentTime = getTimeSinceStateStart();

  if (Application::state.biasVoltage != setpointVoltage) {
    Application::updateBiasVoltage(setpointVoltage);
  }

  if (currentState == State::waiting) {
    Application::updatePiezoVoltage(3, BlindStepper::restPosition);
  } else if (currentState == State::approaching) {
    float progress = float(currentTime) / float(approachTime);
    progress = min(progress, 1);

    float scanAmplitude = 2 * abs(BlindStepper::restPosition);
    float voltage = BlindStepper::restPosition + progress * scanAmplitude;
    Application::updatePiezoVoltage(3, voltage);
  } else if (currentState == State::feedback) {
    float currentMagnitude = abs(Application::state.filteredCurrent);
    currentMagnitude = max(currentMagnitude, 2e-12);
    float dlnI = log(currentMagnitude / setpointCurrent);

    // Position error in meters. Positive means you're too close, correct it
    // by moving backward (more negative voltage).
    float dlnI_dz = 1.025e10 * sqrt(tunnelingBarrierHeight);
    float dz = dlnI / dlnI_dz;
    feedback_diagnostic2 = dz;

    // Try a lowpass filter-like algorithm and extrapolate the small
    // alpha-like constant to equalling 1.0 at a low frequency like 1 kHz.
    // If dln(I)/dz is off by a factor of 2, it's only as if the cutoff
    // frequency is different by a factor of 2.
    float timeProgress = float(KilohertzLoop::period) / float(integratorTimeLag);
    float correctionInMeters = -dz * timeProgress;

    // This catches about 95% of unexplained crashes.
    // 100 ms: crashes recorded
    // 10 ms: crashes recorded (took 350 seconds though)
    // 300 μs: crashes recorded
    // 30 μs: crashes recorded
    //
    // Try making an exponential feedback function that maps the derivative
    // at the setpoint to the position's response.
    if (true) {
      float currentMagnitude = float(Application::state.current);
      if (currentMagnitude > 500e-12) {
        dz = -2;

        if (feedback_diagnostic1 == 0) {
          feedback_diagnostic1 = -1;
        }
      }
    }

    float correctionInVolts = correctionInMeters / 0.320e-9;

    float voltage = Application::state.piezoZVoltage;
    voltage += correctionInVolts;
    voltage = max(-270, voltage);
    voltage = min(270, voltage);
    Application::updatePiezoVoltage(3, voltage);
  }
}

void TipApproacher::writeToLog(uint32_t slotID) {
  Log::ringBuffers[0][slotID] = Application::state.filteredCurrent;
  Log::ringBuffers[1][slotID] = Application::state.piezoZVoltage * 0.320;
  Log::ringBuffers[2][slotID] = feedback_diagnostic1;
  Log::ringBuffers[3][slotID] = feedback_diagnostic2;
  feedback_diagnostic1 = 0;
}