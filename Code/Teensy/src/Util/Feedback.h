#pragma once

#include "NotchFilter.h"

struct Feedback {
  static constexpr float setpointVoltage = 0.050;
  static constexpr float setpointCurrent = 1000e-12;
  static constexpr float tunnelingBarrierHeight = 1.0;
  static constexpr uint32_t integratorTimeLag = 4000; // μs

  static constexpr bool useNotchFilter = false;
  static inline NotchFilter notchFilter;

  static void updatePiezoZ();
};