#include "NotchFilter.h"

#include <Arduino.h>

NotchFilter::NotchFilter() {

}

NotchFilter::NotchFilter(uint32_t samplingPeriod) {
  float samplingFrequency = float(1e6) / float(samplingPeriod);
  float ω0 = 2 * M_PI * resonanceFrequency / samplingFrequency;
  float alpha = sin(ω0) / (2 * Q);

  b[0] = 1;
  b[1] = -2 * cos(ω0);
  b[2] = 1;
  a[0] = 1 + alpha;
  a[1] = -2 * cos(ω0);
  a[2] = 1 - alpha;

  float normalizingFactor = 1 / a[0];
  for (uint32_t i = 0; i < 3; ++i) {
    b[i] *= normalizingFactor;
    a[i] *= normalizingFactor;
  }
}

float NotchFilter::getOutput() const {
  return y1;
}

void NotchFilter::update(float input) {
  float output = 0;
  output += b[0] * input + b[1] * x1 + b[2] * x2;
  output -= a[1] * y1 + a[2] * y2;
  
  // Shift delay lines.
  x2 = x1;
  x1 = input;
  y2 = y1;
  y1 = output;
}