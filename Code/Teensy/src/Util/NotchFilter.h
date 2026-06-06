#pragma once

#include <stdint.h>

struct NotchFilter {
  static constexpr float resonanceFrequency = 1470;
  static constexpr float Q = 1.0;
  
  NotchFilter();
  NotchFilter(bool notDefaultConstructor);
  
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