#pragma once

#include "Command/Parsing/Command.h"
#include "Util/Vector/Vector.h"

namespace Tilt {
  struct Settings {
    static inline float2 slope = float2(0);
    static void forwardState();
    static void update(Command command);
  };
};