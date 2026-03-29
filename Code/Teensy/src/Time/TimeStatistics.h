#pragma once

#include <stdint.h>

struct TimeStatistics {
  uint32_t above1000000us_jumps = 0;
  uint32_t above100000us_jumps = 0;
  uint32_t above10000us_jumps = 0;
  uint32_t above1000us_jumps = 0;
  uint32_t above100us_jumps = 0;
  uint32_t abovePeriod_jumps = 0;
  uint32_t exactlyPeriod_jumps = 0;
  uint32_t underPeriod_jumps = 0;
  uint32_t total_jumps = 0;

  // period - must be less than 100 microseconds
  void integrate(uint32_t jumpDuration, uint32_t period) {
    if (jumpDuration > 1000000) {
      this->above1000000us_jumps += 1;
    } else if (jumpDuration > 100000) {
      this->above100000us_jumps += 1;
    } else if (jumpDuration > 10000) {
      this->above10000us_jumps += 1;
    } else if (jumpDuration > 1000) {
      this->above1000us_jumps += 1;
    } else if (jumpDuration > 100) {
      this->above100us_jumps += 1;
    } else if (jumpDuration > period) {
      this->abovePeriod_jumps += 1;
    } else if (jumpDuration == period) {
      this->exactlyPeriod_jumps += 1;
    } else if (jumpDuration < period) {
      this->underPeriod_jumps += 1;
    }
    this->total_jumps += 1;
  }
};