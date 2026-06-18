#pragma once

#include "Util/Vector/Vector.h"

inline float interpolate(float start, float end, float t) {
  return start * (1.0f - t) + end * t;
}

inline float2 interpolate(float2 start, float2 end, float t) {
  return start * (1.0f - t) + end * t;
}
