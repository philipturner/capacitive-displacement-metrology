#pragma once

#include <stdint.h>

namespace Creep {
  namespace Harmonics {
    bool isRoundTripSafe(uint32_t iterations);
    uint32_t nextSafeRoundTrip(uint32_t iterations);
  };
};