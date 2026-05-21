#include "BlindStepper.h"

#include "Misc/Application.h"
#include "Time/KilohertzLoop.h"
#include <Arduino.h>

BlindStepper::Mode getMode(uint32_t code) {
  char character = char(code);
  if (character == 'u') {
    return BlindStepper::Mode::up;
  } else if (character == 'd') {
    return BlindStepper::Mode::down;
  } else if (character == 'c') {
    return BlindStepper::Mode::capacitance;
  } else {
    Serial.println("This should never happen.");
    exit(0);
  }
}

BlindStepper::BlindStepper() {

}

BlindStepper::BlindStepper(uint32_t *attributes) {
  mode = getMode(attributes[0]);

  if (mode == Mode::up || mode == Mode::down) {
    stepsPerCheck = attributes[1];
  } else if (mode == Mode::capacitance) {
    stepsPerCheck = attributes[2];
    capacitanceThreshold = float(attributes[1]) / 10000;
  }

  Application::capTracker = CapacitanceTracker(true);
  currentState = State::measuring;
}

float BlindStepper::sawtoothWave(uint32_t waveIterationDelta) {
  if (wavePeriod % (2 * KilohertzLoop::period) != 0) {
    Serial.println("Blind stepper wave period not sufficiently divisible.");
    exit(0);
  }
  uint32_t itersPerWave = wavePeriod / KilohertzLoop::period;
  uint32_t phase = waveIterationDelta % itersPerWave;
  uint32_t halfPoint = itersPerWave / 2;

  float output = 0;
  if (mode == Mode::up || mode == Mode::capacitance) {
    output = restPosition;
    if (phase <= halfPoint) {
      float progress = float(phase) / float(halfPoint);
      output += progress * stepUpAmplitude;
    }
  } else if (mode == Mode::down) {
    output = restPosition + stepDownAmplitude;
    if (phase >= halfPoint) {
      float progress = float(phase - halfPoint) / float(halfPoint);
      output -= progress * stepDownAmplitude;
    }
  }
  return output;
}

void BlindStepper::update() {
  uint32_t itersPerWaveSequence = wavePeriod / KilohertzLoop::period;
  itersPerWaveSequence *= stepsPerCheck;

  if (waveStartIterationID == UINT32_MAX) {
    Serial.println("Wave start iteration was not set.");
    exit(0);
  }
  uint32_t waveIterationDelta = KilohertzLoop::iterationID - waveStartIterationID;
  if (currentState == State::stepping && waveIterationDelta >= itersPerWaveSequence) {
    currentState = State::measuring;
    cycleID += 1;
    waveStartIterationID = UINT32_MAX;
  }

  if (currentState == State::measuring) {
    // Does not update the bias voltage if the capacitance tracker finishes.
    Application::updateCapacitanceTracker(/*regenerate=*/false);

    auto state = Application::capTracker.getCurrentState();
    if (state == CapacitanceTracker::State::finished) {
      if (mode == Mode::up || mode == Mode::down) {
        if (cycleID > 0) {
          currentState = State::finished;
        } else {
          currentState = State::stepping;
        }
      } else if (mode == Mode::capacitance) {
        float capacitance = Application::state.capacitance;
        if (capacitance > capacitanceThreshold) {
          currentState = State::finished;
        } else {
          currentState = State::stepping;
        }
      }
      waveStartIterationID = KilohertzLoop::iterationID;
    }
  }

  if (currentState == State::stepping) {
    Application::updateBiasVoltage(0);

    float voltage = sawtoothWave(waveIterationDelta);
    Application::updatePiezoZVoltage(voltage);
  } else {
    Application::updatePiezoZVoltage(BlindStepper::restPosition);
  }
}