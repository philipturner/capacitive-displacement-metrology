#pragma once

#include <math.h>
#include <stdint.h>

struct FirstOrderLowpassFilter {
  static float getAlpha(
    float frequency,
    uint32_t loopPeriodMicros
  ) {
    float sampleTimeSeconds = float(1e-6) * float(loopPeriodMicros);
    float timeConstant = 1 / (2 * M_PI * frequency);
    return sampleTimeSeconds / (timeConstant + sampleTimeSeconds);
  }
};