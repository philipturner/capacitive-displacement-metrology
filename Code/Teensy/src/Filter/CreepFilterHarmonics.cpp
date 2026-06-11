#include "CreepFilter.h"

#include <math.h>

bool CreepFilter::isRoundTripSafe(uint32_t iterations) {
  if (iterations <= 8) {
    return false;
  }

  float power2 = log2(float(iterations));
  float nearestPower2 = round(power2);
  float difference = abs(power2 - nearestPower2);
  if (difference < 0.10) {
    return false;
  }

  return true;
}

uint32_t CreepFilter::nextSafeRoundTrip(uint32_t iterations) {
  if (iterations <= 8) {
    return 9;
  }

  float power2 = log2(float(iterations));
  float nearestPower2 = round(power2);

  float output = exp2(nearestPower2 + 0.1);
  output = ceil(output);
  return uint32_t(output);
}