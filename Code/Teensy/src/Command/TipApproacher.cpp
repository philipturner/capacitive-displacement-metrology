#include "TipApproacher.h"

#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include "Util/Feedback.h"
#include <Arduino.h>

TipApproacher::TipApproacher() {

}

TipApproacher::TipApproacher(bool notDefaultConstructor) {
  currentState = State::preWait;
  segmentStartIterationID = KilohertzLoop::iterationID;
}

bool isRetracted(float voltageZ) {
  float targetVoltage = -130;
  float dV = voltageZ - targetVoltage;
  return abs(dV) < 0.05;
}

float retract(float input, float dV) {
  float output = input;
  if (input < -130) {
    output += dV;
    output = min(output, -130);
  } else {
    output += -dV;
    output = max(output, -130);
  }
  return output;
}

void TipApproacher::update() {
  updateState();

  Application::updateBiasVoltage(Feedback::setpointVoltage);

  if (currentState == State::finished) {
    Feedback::updatePiezoZ();
  } else {
    float voltageZ = getPiezoVoltage();
    Application::updatePiezoVoltage(3, voltageZ);
  }
}

void TipApproacher::updateState() {
  previousState = currentState;

  uint32_t deltaIters = getIterationsSinceStart();
  uint32_t time = deltaIters * KilohertzLoop::period;
  float voltageZ = Application::state.piezoZVoltage;

  switch (previousState) {
    case State::preWait: {
      if (isRetracted(voltageZ)) {
        currentState = State::wait;
      }
      break;
    }
    case State::wait: {
      if (time >= 1000) {
        currentState = State::approach;
      }
      break;
    }
    case State::approach: {
      if (voltageZ >= 270) {
        currentState = State::preStep;
      }
      break;
    }
    case State::preStep: {
      if (voltageZ <= 130) {
        currentState = State::stepAndWait;
      }
      break;
    }
    case State::stepAndWait: {
      if (time >= 600) {
        currentState = State::preWait;
      }
      break;
    };
    case State::retract: {
      if (isRetracted(voltageZ)) {
        currentState = State::finished;
      }
      break;
    }
    case State::finished: {
      break;
    }
  }

  if (currentState == State::approach) {
    float current = Application::state.current;
    float setpoint = Feedback::setpointCurrent;
    if (abs(current) >= setpoint) {
      currentState = State::retract;
      Application::state.positionError = 0.5e-9;
    }
  }

  if (currentState != previousState) {
    segmentStartIterationID = KilohertzLoop::iterationID;
  }
}

uint32_t TipApproacher::getIterationsSinceStart() {
  uint32_t deltaIters = KilohertzLoop::iterationID;
  deltaIters -= segmentStartIterationID;
  return deltaIters;
}

float TipApproacher::getPiezoVoltage() {
  float dt = float(KilohertzLoop::period) * 1e-6;
  float voltageZ = Application::state.piezoZVoltage;

  switch (currentState) {
    case State::preWait: {
      float dVdt = float(840) / float(600e-6);
      float dV = dVdt * dt;
      voltageZ = retract(voltageZ, dV);
      break;
    }
    case State::wait: {
      voltageZ = -130;
      break;
    }
    case State::approach: {
      float dVdt = float(1000e-9) / float(0.320e-9);
      voltageZ += dVdt * dt;
      voltageZ = min(voltageZ, 270);
      break;
    }
    case State::preStep: {
      float dVdt = float(840) / float(600e-6);
      voltageZ += -dVdt * dt;
      voltageZ = max(voltageZ, 130);
      break;
    }
    case State::stepAndWait: {
      voltageZ = -270;
      break;
    }
    case State::retract: {
      uint32_t deltaIters = getIterationsSinceStart();

      // if (deltaIters >= 100) {
        float dVdt = float(840) / float(600e-6);
        float dV = dVdt * dt;
        voltageZ = retract(voltageZ, dV);
      // } else if (deltaIters >= 30 && deltaIters < 35) {
      //   //voltageZ += -2e-9 / 0.320e-9;
      // } else if (deltaIters == 60) {

      // }

      break;
    }
    case State::finished: {
      voltageZ = -130;
      break;
    }
  }

  return voltageZ;
}
