#pragma once

#include "Util/Vector.h"
#include <stdint.h>

namespace Creep {
  struct Sample {
    float2 dV = 0;
    uint32_t twiceQueueTime = 0;
    float trueTimeOffset = 0;

    Sample();

    Sample(Sample source1, Sample source2);
  };
};