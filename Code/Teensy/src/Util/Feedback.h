#pragma once

#include <stdint.h>

struct Feedback {
  static constexpr float setpointVoltage = 0.050;

  static constexpr float setpointCurrent = 10e-12;

  static constexpr float tunnelingBarrierHeight = 1.0;

  static constexpr uint32_t integratorTimeLag = 4000; // μs

  static void updatePiezoZ();
};