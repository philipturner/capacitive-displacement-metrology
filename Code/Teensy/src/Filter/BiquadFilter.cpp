#include "BiquadFilter.h"

#include "Time/KilohertzLoop.h"
#include <Arduino.h>

BiquadFilter::BiquadFilter() {

}

BiquadFilter::BiquadFilter(
  float resonanceFrequency, 
  float Q, 
  BiquadFilter::Type type
) {
  uint32_t samplingPeriod = KilohertzLoop::period;
  float samplingFrequency = float(1e6) / float(samplingPeriod);
  float ω0 = 2 * M_PI * resonanceFrequency / samplingFrequency;
  float alpha = sin(ω0) / (2 * Q);

  switch (type) {
    case Type::secondOrderLowpass: {
      b[0] = (1 - cos(ω0)) / 2;
      b[1] = 1 - cos(ω0);
      b[2] = (1 - cos(ω0)) / 2;
      a[0] = 1 + alpha;
      a[1] = -2 * cos(ω0);
      a[2] = 1 - alpha;
      break;
    }
    case Type::notch: {
      b[0] = 1;
      b[1] = -2 * cos(ω0);
      b[2] = 1;
      a[0] = 1 + alpha;
      a[1] = -2 * cos(ω0);
      a[2] = 1 - alpha;
      break;
    }
  }
  
  float normalizingFactor = 1 / a[0];
  for (uint32_t i = 0; i < 3; ++i) {
    b[i] *= normalizingFactor;
    a[i] *= normalizingFactor;
  }
}

float BiquadFilter::getOutput() const {
  return y1;
}

void BiquadFilter::update(float input) {
  float output = 0;
  output += b[0] * input + b[1] * x1 + b[2] * x2;
  output -= a[1] * y1 + a[2] * y2;
  
  // Shift delay lines.
  x2 = x1;
  x1 = input;
  y2 = y1;
  y1 = output;
}