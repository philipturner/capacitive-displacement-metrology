#include "Sample.h"

#include <math.h>

using namespace Creep;

float getMagnitude(Sample sample) {
  float2 dV_squared = sample.dV * sample.dV;
  float accumulator = dV_squared.x + dV_squared.y;
  return sqrt(accumulator);
}

float getWeightedTime(Sample source1, Sample source2) {
  float relativeTime1 = source1.trueTimeOffset;
  float relativeTime2 = source2.trueTimeOffset;
  relativeTime2 += float(source2.queueTime - source1.queueTime);

  float magnitude1 = getMagnitude(source1);
  float magnitude2 = getMagnitude(source2);
  if (magnitude1 + magnitude2 < 1e-6f) {
    return (relativeTime1 + relativeTime2) / 2.0f;
  }

  float accumulator = 0;
  accumulator += relativeTime1 * magnitude1;
  accumulator += relativeTime2 * magnitude2;
  accumulator /= magnitude1 + magnitude2;
  return accumulator;
}

Sample::Sample() {

}

Sample::Sample(Sample source1, Sample source2) {
  dV = source1.dV + source2.dV;
  queueTime = (source1.queueTime + source2.queueTime) / 2.0f;

  trueTimeOffset = getWeightedTime(source1, source2);
  trueTimeOffset -= float(queueTime - source1.queueTime);
}