#pragma once

#include <stdint.h>

struct Feedback {
  static constexpr float setpointVoltage = 0.050;

  static constexpr float setpointCurrent = 100e-12;

  // Tunneling barrier height is not known precisely from the literature.
  // Supposedly, ambient contamination lowers it from 4.0-4.5 V in vacuum
  // to 0.5-1.2 V under ambient conditions.
  //
  // 4.0 V -> 112 pm per decade
  // 1.0 V -> 225 pm per decade
  // 0.5 V -> 318 pm per decade
  static constexpr float tunnelingBarrierHeight = 1.0;

  static constexpr uint32_t integratorTimeLag = 1000; // μs

  static void updatePiezoZ();
};