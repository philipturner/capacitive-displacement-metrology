#include "Harmonics.h"

#include <math.h>

bool Creep::Harmonics::isRoundTripSafe(uint32_t iterations) {
  if (iterations <= 8) {
    return false;
  }

  float power2 = log2f(float(iterations));
  float nearestPower2 = roundf(power2);
  float difference = abs(power2 - nearestPower2);
  if (difference < 0.10f) {
    return false;
  }

  return true;
}

uint32_t Creep::Harmonics::nextSafeRoundTrip(uint32_t iterations) {
  if (iterations <= 8) {
    return 9;
  }

  float power2 = log2f(float(iterations));
  float nearestPower2 = roundf(power2);

  float output = exp2f(nearestPower2 + 0.1f);
  output = ceilf(output);
  return uint32_t(output);
}