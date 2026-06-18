#pragma once

#include "Time/KilohertzLoop.h"
#include <math.h>

struct FirstOrderLowpassFilter {
  static float getAlpha(float frequency) {
    float sampleTimeSeconds = float(1e-6) * float(KilohertzLoop::period);
    float timeConstant = 1.0f / (2.0f * float(M_PI) * frequency);
    return sampleTimeSeconds / (timeConstant + sampleTimeSeconds);
  }
};