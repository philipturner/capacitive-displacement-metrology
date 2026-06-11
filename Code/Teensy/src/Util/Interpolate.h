#pragma once

#include "Vector.h"

float interpolate(float start, float end, float t) {
  return start * (1 - t) + end * t;
}

float2 interpolate(float2 start, float2 end, float t) {
  return start * (1 - t) + end * t;
}