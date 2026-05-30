#pragma once

#include <stdint.h>

struct Feedback {
  static constexpr float setpointVoltage = 1.000;

  static constexpr float setpointCurrent = 1000e-12;

  static constexpr float tunnelingBarrierHeight = 1.0;

  static constexpr uint32_t integratorTimeLag = 4000; // μs

  static void updatePiezoZ();
};