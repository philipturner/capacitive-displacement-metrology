#include "BlindStepper.h"

#include "Misc/Application.h"
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
  measuringCapacitance = true;
}

void BlindStepper::update() {
  // TODO: Continue here.
}