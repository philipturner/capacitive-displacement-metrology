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
  float targetVoltage = -80;
  float dV = voltageZ - targetVoltage;
  return abs(dV) < 0.05;
}

float retract(float input, float dV) {
  float output = input;
  if (input < -80) {
    output += dV;
    output = min(output, -80);
  } else {
    output += -dV;
    output = max(output, -80);
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
      if (voltageZ <= 0) {
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
      if (Application::state.piezoZVoltage >= 270) {
        if (time >= 100000) {
          currentState = State::preStep;
        }
      }
      break;
    }
  }

  if (currentState == State::approach) {
    float current = Application::state.current;
    float setpoint = Feedback::setpointCurrent;
    if (abs(current) >= setpoint) {
      currentState = State::retract;
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
      voltageZ = -80;
      break;
    }
    case State::approach: {
      // Retracting at 840 V / 600 μs
      // Δx_equilibrium reaches -5.4 nm in 12 μs
      // acceleration reaches -0.46 m/s^2 at 1.47 kHz resonance
      // 1000 nm/s velocity comes to a stop in 2.2 μs
      float speed = float(50e-12) / float(64e-6 + 12e-6 + 2.2e-6);
      speed *= 0.80; // 80% derating factor
      
      float dVdt = speed / float(0.320e-9);
      voltageZ += dVdt * dt;
      voltageZ = min(voltageZ, 270);
      break;
    }
    case State::preStep: {
      float dVdt = float(840) / float(600e-6);
      voltageZ += -dVdt * dt;
      voltageZ = max(voltageZ, 0);
      break;
    }
    case State::stepAndWait: {
      voltageZ = -270;
      break;
    }
    case State::retract: {
      float dVdt = float(840) / float(600e-6);
      float dV = dVdt * dt;
      voltageZ = retract(voltageZ, dV);
      break;
    }
    case State::finished: {
      voltageZ = -80;
      break;
    }
  }

  return voltageZ;
}
