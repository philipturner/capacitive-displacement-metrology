#pragma once

#include <stdint.h>
#include <Arduino.h>

namespace Creep {
  struct LookupTable {
    static constexpr uint32_t supersamplingRate = 10;
    static constexpr uint32_t resolution = 32;
    static constexpr uint32_t binCount = 1 + supersamplingRate * resolution;

    static inline float bins[binCount];

    LookupTable();
    LookupTable(bool notDefaultConstructor);

    uint32_t getBinID(float dt) const {
      float rounded = dt;
      rounded *= float(resolution);
      rounded += 0.5;
      return uint32_t(rounded);
    }
  };
};