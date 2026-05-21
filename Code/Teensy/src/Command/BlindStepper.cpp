#include "BlindStepper.h"

#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include <Arduino.h>

BlindStepper::Mode getMode(char code) {
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
    capacitanceThreshold = float(command.attributes[0]) / 10000;
    stepsPerCheck = command.attributes[1];
  }

  Application::capTracker = CapacitanceTracker(true);
  currentState = State::measuring;
}

float BlindStepper::sawtoothWave(
  uint32_t waveIterationDelta,
  BlindStepper::Mode mode
) {
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

    float voltage = sawtoothWave(waveIterationDelta, mode);
    Application::updatePiezoZVoltage(voltage);
  } else {
    Application::updatePiezoZVoltage(BlindStepper::restPosition);
  }
}