#pragma once

#include <stdint.h>

struct CreepFilter {
  static bool isRoundTripSafe(uint32_t iterations);
  static uint32_t nextSafeRoundTrip(uint32_t iterations);
};