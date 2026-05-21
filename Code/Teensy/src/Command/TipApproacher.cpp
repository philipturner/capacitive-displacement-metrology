#include "TipApproacher.h"

#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include "Util/FilterUtil.h"
#include <Arduino.h>

TipApproacher::TipApproacher() {
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
  previousState = currentState;
  uint32_t previousTime = getTimeSinceStateStart();

  // Implementation is still in progress.

  if (currentState == State::forwardStepping) {
    auto state = blindStepper.getCurrentState();
    if (state == BlindStepper::State::finished) {
      currentState = State::waiting;
    }
  } else if (currentState == State::waiting) {

  } else if (currentState == State::approaching) {

  } else if (currentState == State::retracting) {

  } else if (currentState == State::feedback) {

  }

  if (currentState != previousState) {
    stateStartIterationID = KilohertzLoop::iterationID;

    if (currentState == State::forwardStepping) {
      Command command;
      command.mode = Command::Mode::blindStepping;
      command.alphaCode = 'u';
      command.attributes[0] = 1;
      blindStepper = BlindStepper(command);
    } else if (currentState == State::waiting) {

    } else if (currentState == State::approaching) {

    } else if (currentState == State::retracting) {

    } else if (currentState == State::feedback) {

    }
  }

  if (currentState == State::forwardStepping) {
    blindStepper.update();
  } else if (currentState == State::waiting) {
    Application::updatePiezoVoltage(3, BlindStepper::restPosition);
    Application::updateBiasVoltage(0);
  } else if (currentState == State::approaching) {

  } else if (currentState == State::retracting) {

  } else if (currentState == State::feedback) {
    // dln(I)/dz = -1.025e10 * sqrt(tunnelingBarrierHeight)
    //
    // Try a lowpass filter-like algorithm and extrapolate the small
    // alpha-like constant to equalling 1.0 at a low frequency like 1 kHz.
    // If dln(I)/dz is off by a factor of 2, it's only as if the cutoff
    // frequency is different by a factor of 2.
  }
}

uint32_t TipApproacher::getTimeSinceStateStart() {
  uint32_t deltaIters = KilohertzLoop::iterationID;
  deltaIters -= stateStartIterationID;
  return deltaIters * KilohertzLoop::period;
}