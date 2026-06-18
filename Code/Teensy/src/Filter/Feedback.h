#pragma once

#include "Filter/NotchFilter.h"
#include "Util/Vector/Vector.h"

struct Feedback {
  static constexpr float setpointVoltage = 0.050;
  static constexpr float setpointCurrent = 1000e-12;
  static constexpr float tunnelingBarrierHeight = 1.0;
  static constexpr uint32_t integratorTimeLag = 500; // μs

  static constexpr bool useNotchFilter = true;
  static inline NotchFilter notchFilter;

  // Enter the raw current signal, with as little filtering as possible.
  static float getVoltageCorrection(float current);
};