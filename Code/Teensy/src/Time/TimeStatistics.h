#pragma once

#include <stdint.h>

struct TimeStatistics {
  static constexpr uint32_t binCount = 100;
  uint32_t bins[binCount]; // may cause program to fail to upload
  uint32_t largeJumpCount = 0;
  uint32_t totalJumpCount = 0;

  TimeStatistics() {
    for (uint32_t binID = 0; binID < binCount; ++binID) {
      bins[binID] = 0;
    }
  }

  void integrate(uint32_t jumpDuration, uint32_t period) {
    if (jumpDuration < binCount) {
      bins[jumpDuration] += 1;
    } else {
      largeJumpCount += 1;
    }
    totalJumpCount += 1;
  }

  void display();
};