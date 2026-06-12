#pragma once

#include "Util/Vector.h"
#include <stdint.h>

namespace Creep {
  struct Sample {
    float2 dV = 0;
    float time = 0;
    float queueTime = 0;

    Sample();

    Sample(Sample source1, Sample source2);
  };
};