#pragma once

#include "Filter/BiquadFilter.h"

struct Emulation {
  static constexpr float atomSpacing = 0.246; // units: nm
  static constexpr float slopeX = 0.05;
  static constexpr float slopeY = -0.02;
  static constexpr float zeroPositionZ = 10; // units: nm, sign convention of voltage
  
  static inline BiquadFilter secondOrderFilter = BiquadFilter(
    1458, 31.0, BiquadFilter::Type::secondOrderLowpass);
  
  static void updateSecondOrderFilter(float voltageZ);
  static float getCurrent(float voltageX, float voltageY);
};