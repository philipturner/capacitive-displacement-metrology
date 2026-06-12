#include "WaveUtil.h"

#include <math.h>

float WaveUtil::sineWave(float phaseNormalized) {
  return sin(phaseNormalized * 2 * M_PI);
}

float WaveUtil::squareWave(float phaseNormalized) {
  if (phaseNormalized < 0.5) {
    return 1.0;
  } else {
    return -1.0;
  }
}

float WaveUtil::triangleWave(float phaseNormalized) {
  float progress;
  if (phaseNormalized < 0.5) {
    progress = 2 * phaseNormalized;
  } else {
    progress = 2 * (1 - phaseNormalized);
  }

  return 2 * progress - 1;
}

float WaveUtil::thirdOrderSmoothstep(float x) {
  if (x < 0) {
    return 0;
  }
  if (x > 1) {
    return 1;
  }

  float x2 = x * x;
  float x3 = x2 * x;
  float x4 = x2 * x2;

  float output = -20 * x3 + 70 * x2 - 84 * x + 35;
  output *= x4;
  return output;
}

float WaveUtil::polynomialWaveOutskirt(float x) {
  float x2 = x * x;
  float x3 = x2 * x;
  float x5 = x2 * x2 * x;
  
  float output = -2.5 * x3 + 10 * x2 - 14 * x + 7;
  output *= x5;
  return output;
}

float WaveUtil::polynomialWaveBend(float x) {
  float x2 = x * x;
  float x3 = x2 * x;
  float x5 = x2 * x2 * x;
  
  float output = -2.5 * x3 + 10 * x2 - 14 * x + 7;
  output *= 2;
  output *= x5;
  output += -x + 0.5;
  return output;
}