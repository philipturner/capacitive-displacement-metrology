#include "Settings.h"

#include "Diagnostics/Log.h"

using namespace Tilt;

void Settings::update(Command command) {
  slope.x = command.attributes[0];
  slope.y = command.attributes[1];
}

void Settings::forward() {
  Log::write(
    Log::Flags::tiltSettings,
    slope.x,
    slope.y);
}

float Settings::getRelativeZ(float x, float y, float z) {
  float predictedZ = 0;
  predictedZ += slope.x * x;
  predictedZ += slope.y * y;
  return z - predictedZ;
}