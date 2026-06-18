#include "Settings.h"

#include "Diagnostics/Log.h"
#include <Arduino.h>

using namespace Tilt;

void Settings::forwardState() {
  Log::writeValuesWithFlags(
    8, // flags
    slope.x,
    slope.y);
}

void Settings::update(Command command) {
  if (command.alphaCode != 't') {
    Serial.println("This should never happen.");
    exit(0);
  }

  slope.x = command.attributes[0];
  slope.y = command.attributes[1];
}