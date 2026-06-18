#include "WaveUtil.h"

#include <math.h>

float WaveUtil::sineWave(float phaseNormalized) {
  return sinf(phaseNormalized * float(2 * M_PI));
}

float WaveUtil::squareWave(float phaseNormalized) {
  if (phaseNormalized < 0.5f) {
    return 1.0;
  } else {
    return -1.0;
  }
}

float WaveUtil::triangleWave(float phaseNormalized) {
  float progress;
  if (phaseNormalized < 0.5f) {
    progress = 2.0f * phaseNormalized;
  } else {
    progress = 2.0f * (1.0f - phaseNormalized);
  }

  return 2.0f * progress - 1.0f;
}

float WaveUtil::thirdOrderSmoothstep(float x) {
  if (x < 0.0f) {
    return 0;
  }
  if (x > 1.0f) {
    return 1;
  }

  float x2 = x * x;
  float x3 = x2 * x;
  float x4 = x2 * x2;

  float output = -20.0f * x3 + 70.0f * x2 - 84.0f * x + 35.0f;
  output *= x4;
  return output;
}

float WaveUtil::polynomialWaveOutskirt(float x) {
  float x2 = x * x;
  float x3 = x2 * x;
  float x5 = x2 * x2 * x;
  
  float output = -2.5f * x3 + 10.0f * x2 - 14.0f * x + 7.0f;
  output *= x5;
  return output;
}

float WaveUtil::polynomialWaveBend(float x) {
  float x2 = x * x;
  float x3 = x2 * x;
  float x5 = x2 * x2 * x;
  
  float output = -2.5f * x3 + 10.0f * x2 - 14.0f * x + 7.0f;
  output *= 2.0f;
  output *= x5;
  output += -x + 0.5f;
  return output;
}