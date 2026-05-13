#pragma once

#include <stdint.h>

namespace FilterUtil {
  float sineWave(float phaseNormalized);
  float squareWave(float phaseNormalized);
  float triangleWave(float phaseNormalized);

  float getLowpassAlpha(float frequency, uint32_t loopPeriodMicros);
};