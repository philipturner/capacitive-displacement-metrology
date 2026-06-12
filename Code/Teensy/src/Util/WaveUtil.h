#pragma once

#include <stdint.h>

namespace WaveUtil {
  float sineWave(float phaseNormalized);
  float squareWave(float phaseNormalized);
  float triangleWave(float phaseNormalized);

  float thirdOrderSmoothstep(float x);

  // x = 0   -> y = 0.000, y' = 0
  // x = 0.5 -> y = 0.068
  // x = 1   -> y = 0.500, y' = 1
  float polynomialWaveOutskirt(float x);

  // x = 0   -> y = 0.500, y' = -1
  // x = 0.5 -> y = 0.137, y' = 0
  // x = 1   -> y = 0.500, y' = 1
  //
  // 0.137 = 35 / 256
  float polynomialWaveBend(float x);
};