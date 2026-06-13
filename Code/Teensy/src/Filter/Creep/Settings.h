#pragma once

#include "Command/Parsing/Command.h"
#include "Util/Vector.h"
#include <stdint.h>

namespace Creep {
  struct Settings {
    static constexpr uint32_t logScaleResolution = 100; // 4;
    static constexpr uint32_t queueCount = 1; // 33;
    static constexpr float supersamplingRate = 10;

    static inline float2 creepConstants = float2(0);

    static void update(Command command); // TODO
  };
};