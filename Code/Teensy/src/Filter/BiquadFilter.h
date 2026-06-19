#pragma once

#include <stdint.h>

struct BiquadFilter {
  enum Type {
    secondOrderLowpass = 0,
    notch = 1,
  };
  
  BiquadFilter();
  BiquadFilter(float resonanceFrequency, float Q, Type type);
  
  float getOutput() const;

  void update(float input);

private:
  float b[3];
  float a[3];

  float x2 = 0;
  float x1 = 0;
  float y2 = 0;
  float y1 = 0;
};