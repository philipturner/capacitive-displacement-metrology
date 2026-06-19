#pragma once

#include "Filter/BiquadFilter.h"
#include "Util/Vector/Vector.h"

struct Feedback {
  static constexpr float setpointVoltage = 0.050;
  static constexpr float setpointCurrent = 1000e-12;
  static constexpr float tunnelingBarrierHeight = 1.0;
  
  // suppresses f0 = 1400 Hz, Q = 17
  // suppresses f0 = 1458 Hz, Q = 68
  static constexpr uint32_t defaultTimeConstant = 500; // μs
  static inline uint32_t timeConstant = defaultTimeConstant;
  static inline BiquadFilter notchFilter = BiquadFilter(
    1626, 1.0, BiquadFilter::Type::notch);

  // Enter the raw current signal, with as little filtering as possible.
  static float getVoltageCorrection(float current);
};