#pragma once

#include <stdint.h>

struct Timestamp {
  uint32_t upperHalf = 0;
  uint32_t lowerHalf = 0;

  void raiseLowerHalf(uint32_t input) {
    if (input < lowerHalf) {
      upperHalf += 1;
    }
    lowerHalf = input;
  }

  int64_t getLongValue() {
    return (int64_t(upperHalf) << 32) | lowerHalf;
  }
};
