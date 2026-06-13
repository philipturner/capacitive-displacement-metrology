#pragma once

#include <stdint.h>

namespace Creep {
  struct LookupTable {
    static constexpr uint32_t supersamplingRate = 10;
    static constexpr uint32_t resolution = 32;
  };
};