#include "TipApproacher.h"

#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include "Filter/Feedback.h"
#include <Arduino.h>

TipApproacher::TipApproacher() {

}

TipApproacher::TipApproacher(TipApproacher::State startingState) {
  if (startingState == State::feedback) {
    didContact = true;
    skipRetractBeforeFeedback = true;
  }
  currentState = startingState;
  stateStartIterationID = KilohertzLoop::iterationID;
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

void TipApproacher::updatePiezoZ() {
  updateState();

  float voltageZ = getPiezoVoltage();
  Application::updatePiezoVoltage(3, voltageZ);
}

uint32_t TipApproacher::getIterationsSinceStateStart() {
  uint32_t deltaIters = KilohertzLoop::iterationID;
  deltaIters -= stateStartIterationID;
  return deltaIters;
}

void TipApproacher::updateState() {
  previousState = currentState;

  uint32_t deltaIters = getIterationsSinceStateStart();
  uint32_t time = deltaIters * KilohertzLoop::period;

  switch (previousState) {
    case State::waitBeforeApproach: {
      if (time >= 1250) {
        currentState = State::approach;
      }
      break;
    }
    case State::approach: {
      if (Application::state.piezoZVoltage >= 270) {
        currentState = State::stepUp;
      } else {
        float current = Application::state.current;
        float setpoint = Feedback::setpointCurrent;
        if (abs(current) >= setpoint) {
          currentState = State::feedback;
          didContact = true;
        }
      }
      break;
    }
    case State::stepUp: {
      if (time >= 800) {
        currentState = State::waitBeforeApproach;
      }
      break;
    }
    case State::stepDown: {
      if (time >= 1600) {
        currentState = State::approach;
      }
      break;
    }
    case State::feedback: {
      break;
    }
  }

  if (currentState == State::feedback) {
    float voltageZ = Application::state.piezoZVoltage;
    if (voltageZ >= 250) {
      currentState = State::stepUp;
    } else if (voltageZ <= -60) {
      currentState = State::stepDown;
    }
  }

  if (currentState != previousState) {
    stateStartIterationID = KilohertzLoop::iterationID;
    skipRetractBeforeFeedback = false;
  }
}

float TipApproacher::getPiezoVoltage() {
  uint32_t deltaIters = getIterationsSinceStateStart();
  float voltageZ = Application::state.piezoZVoltage;

  switch (currentState) {
    case State::waitBeforeApproach: {
      float dV = 1.4 * float(KilohertzLoop::period);
      if (voltageZ < -80) {
        return min(voltageZ + dV, -80);
      } else if (voltageZ > -80) {
        return max(voltageZ - dV, -80);
      } else {
        return -80;
      }
    }
    case State::approach: {
      // Retracting at 840 V / 600 μs
      // Δx_equilibrium reaches -5.4 nm in 12 μs
      // acceleration reaches -0.46 m/s^2 at 1.47 kHz resonance
      // 1000 nm/s velocity comes to a stop in 2.2 μs
      float speed = float(50e-12) / float(64e-6 + 12e-6 + 2.2e-6);
      
      float dVdt = speed / float(0.320e-9);
      float dt = float(KilohertzLoop::period) * 1e-6;
      return min(voltageZ + dVdt * dt, 270);
    }
    case State::stepUp: {
      float startVoltage = (didContact ? 20 : 80);

      if (voltageZ > startVoltage) {
        float dV = 1.4 * float(KilohertzLoop::period);
        return max(voltageZ - dV, startVoltage);
      } else {
        return -270;
      }
    }
    case State::stepDown: {
      uint32_t time = deltaIters * KilohertzLoop::period;
      if (time < 600) {
        float dV = 1.4 * float(KilohertzLoop::period);
        return max(voltageZ - dV, -270);
      } else {
        return -80;
      }
    }
    case State::feedback: {
      if (!skipRetractBeforeFeedback && deltaIters < 4) {
        return max(voltageZ - 15, -80);
      } else {
        return Feedback::getVoltage();
      }
    }
  }

  Serial.println("This should never happen.");
  exit(0);
}
