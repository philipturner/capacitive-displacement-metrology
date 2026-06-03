#include "BlindStepper.h"

#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include <Arduino.h>

BlindStepper::Mode BlindStepper::getMode(char code) {
  if (code == 'u') {
    return BlindStepper::Mode::up;
  } else if (code == 'd') {
    return BlindStepper::Mode::down;
  } else if (code == 'c') {
    return BlindStepper::Mode::capacitance;
  } else {
    Serial.println("This should never happen.");
    exit(0);
  }
}

BlindStepper::BlindStepper() {

}

BlindStepper::BlindStepper(Command command) {
  mode = getMode(command.alphaCode);

  if (mode == Mode::up || mode == Mode::down) {
    stepsPerCheck = command.attributes[0];
  } else if (mode == Mode::capacitance) {
    capacitanceThreshold = float(command.attributes[0]) * 0.1e-15;
    stepsPerCheck = command.attributes[1];
  }

  if (mode == Mode::up || mode == Mode::down) {
    currentState = State::retracting;
  } else {
    Application::capTracker = CapacitanceTracker(true);
    currentState = State::measuring;
  }
}

BlindStepper::State
BlindStepper::getCurrentState() const {
  return currentState;
}

void BlindStepper::update() {
  if (currentState == State::retracting && finishedRetracting) {
    currentState = State::stepping;
    waveStartIterationID = KilohertzLoop::iterationID;
  }

  if (currentState == State::stepping) {
    uint32_t itersPerWaveSequence = wavePeriod / KilohertzLoop::period;
    itersPerWaveSequence *= stepsPerCheck;

    uint32_t deltaIters = getIterationsSinceStart();
    if (deltaIters >= itersPerWaveSequence) {
      if (mode == Mode::up || mode == Mode::down) {
        currentState = State::finished;
      } else {
        Application::capTracker = CapacitanceTracker(true);
        currentState = State::measuring;
      }

      waveStartIterationID = UINT32_MAX;
    }
  }

  // This can only happen if the mode is 'capacitance'.
  if (currentState == State::measuring) {
    // Does not update the bias voltage if the capacitance tracker finishes.
    Application::updateCapacitanceTracker(/*regenerate=*/false);

    auto state = Application::capTracker.getCurrentState();
    if (state == CapacitanceTracker::State::finished) {
      float capacitance = Application::state.capacitance;
      if (capacitance > capacitanceThreshold) {
        currentState = State::finished;
      } else {
        currentState = State::stepping;
      }
      waveStartIterationID = KilohertzLoop::iterationID;
    }
  }

  if (currentState == State::measuring) {
    // For some reason, the capacitance measurement is thrown off by writing
    // to the Z DAC here. The problem persists when the high voltage power
    // supply is turned off.
    //
    // I reproduced the same effect by going to any random channel in DAC1.
    // I also reproduce it by adding 'delayMicroseconds(2)' after updating the
    // capacitance tracker. Adding the delay before updating didn't do anything.
    //
    // When migrating the ADC reading to the start of the feedback loop, adding
    // the delay afterward had no effect. Adding the delay before writing to
    // the bias voltage had a massive effect.
    //
    // The lesson is that the timing of DAC updates relative to ADC reads has
    // some kind of effect on the capacitance signal. To make measurements
    // consistent, never vary the timing between updating the bias voltage
    // for capacitance measurement and reading the current.
  } else {
    Application::updateBiasVoltage(0);
    
    if (currentState == State::retracting) {
      float voltage = getRetractVoltage();
      Application::updatePiezoVoltage(3, voltage);
    } else if (currentState == State::stepping) {
      float voltage = getStepWaveVoltage();
      Application::updatePiezoVoltage(3, voltage);
    }
  }
}

uint32_t BlindStepper::getIterationsSinceStart() {
  if (waveStartIterationID == UINT32_MAX) {
    Serial.println("Wave start iteration was not set.");
    exit(0);
  }

  return KilohertzLoop::iterationID - waveStartIterationID;
}

float BlindStepper::getRetractVoltage() {
  float currentVoltage = Application::state.piezoZVoltage;
  float expectedVoltage = 0;

  if (mode == Mode::up || mode == Mode::capacitance) {
    expectedVoltage = 80;
  } else if (mode == Mode::down) {
    expectedVoltage = -270;
  }

  if (currentVoltage > expectedVoltage) {
    float dVdt = float(840) / float(600);
    float dV = -dVdt * float(KilohertzLoop::period);

    float newVoltage = currentVoltage + dV;
    newVoltage = max(newVoltage, expectedVoltage);
    return newVoltage;
  } else {
    finishedRetracting = true;
    return currentVoltage;
  }
}

float BlindStepper::getStepWaveVoltage() {
  uint32_t itersPerWave = wavePeriod / KilohertzLoop::period;
  uint32_t halfPoint = itersPerWave / 2;

  uint32_t deltaIters = getIterationsSinceStart();
  uint32_t phase = deltaIters % itersPerWave;
  
  float output = 0;
  if (mode == Mode::up || mode == Mode::capacitance) {
    output = -270;
    if (phase <= halfPoint) {
      float progress = float(phase) / float(halfPoint);
      output += progress * 350;
    }
  } else if (mode == Mode::down) {
    output = -80;
    if (phase >= halfPoint) {
      float progress = float(phase - halfPoint) / float(halfPoint);
      output += progress * -190;
    }
  }
  return output;
}
