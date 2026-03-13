#pragma once

#include <stdint.h>

struct TimeStatistics {
  uint32_t above1000000us_jumps = 0;
  uint32_t above100000us_jumps = 0;
  uint32_t above10000us_jumps = 0;
  uint32_t above1000us_jumps = 0;
  uint32_t above100us_jumps = 0;
  uint32_t above20us_jumps = 0;
  uint32_t exactly20us_jumps = 0;
  uint32_t under20us_jumps = 0;
  uint32_t total_jumps = 0;

  void integrate(uint32_t jumpDuration);
};
inline TimeStatistics timeStatistics;

