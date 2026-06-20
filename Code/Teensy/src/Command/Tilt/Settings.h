#pragma once

#include "Command/Parsing/Command.h"
#include "Util/Vector/Vector.h"

namespace Tilt {
  struct Settings {
    static inline float2 slope = float2(0);

    static void forwardState(); // forwardSettings
    static void update(Command command);

    static float getRelativeZ(float x, float y, float z);
  };
};