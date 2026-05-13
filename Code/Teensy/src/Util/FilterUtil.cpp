#include "FilterUtil.h"

#include <math.h>

float FilterUtil::sineWave(float phaseNormalized) {
  return sin(phaseNormalized * 2 * M_PI);
}

float FilterUtil::squareWave(float phaseNormalized) {
  if (phaseNormalized < 0.5) {
    return 1.0;
  } else {
    return -1.0;
  }
}

float FilterUtil::triangleWave(float phaseNormalized) {
  float progress;
  if (phaseNormalized < 0.5) {
    progress = 2 * phaseNormalized;
  } else {
    progress = 2 * (1 - phaseNormalized);
  }

  return 2 * progress - 1;
}

float FilterUtil::getLowpassAlpha(
  float frequency, 
  uint32_t loopPeriodMicros
) {
  float sampleTimeSeconds = float(1e-6) * float(loopPeriodMicros);
  float timeConstant = 1 / (2 * M_PI * frequency);
  return sampleTimeSeconds / (timeConstant + sampleTimeSeconds);
}