#include "TipApproacher.h"

#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include <Arduino.h>

TipApproacher::TipApproacher() {

}

TipApproacher::TipApproacher(bool notDefaultConstructor) {
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
  Application::updateBiasVoltage(setpointVoltage);

  if (Application::state.biasVoltage != setpointVoltage) {
    
  }

  // Change so it cannot suddenly jump to a specific voltage anymore.
  if (currentState == State::waiting) {
    Application::updatePiezoVoltage(3, BlindStepper::restPosition);
  } else if (currentState == State::approaching) {
    float progress = float(currentTime) / float(approachTime);
    progress = min(progress, 1);

    float scanAmplitude = 2 * abs(BlindStepper::restPosition);
    float voltage = BlindStepper::restPosition + progress * scanAmplitude;
    Application::updatePiezoVoltage(3, voltage);
  } else if (currentState == State::feedback) {
    
  }
}
