#include "Sample.h"

#include <math.h>

#include <Arduino.h> // temp; debugging

using namespace Creep;

float getMagnitude(Sample sample) {
  float2 dV_squared = sample.dV * sample.dV;
  float accumulator = dV_squared.x + dV_squared.y;
  return sqrt(accumulator);
}

float getWeightedTime(Sample source1, Sample source2) {
  float magnitude1 = getMagnitude(source1);
  float magnitude2 = getMagnitude(source2);
  if (magnitude1 + magnitude2 < 1e-6) {
    return (source1.time + source2.time) / 2;
  }

  float accumulator = 0;
  accumulator += source1.time * magnitude1;
  accumulator += source2.time * magnitude2;
  accumulator /= magnitude1 + magnitude2;
  return accumulator;
}

Sample::Sample() {

}

Sample::Sample(Sample source1, Sample source2) {
  dV = source1.dV + source2.dV;
  time = getWeightedTime(source1, source2);
  queueTime = (source1.queueTime + source2.queueTime) / 2;
}