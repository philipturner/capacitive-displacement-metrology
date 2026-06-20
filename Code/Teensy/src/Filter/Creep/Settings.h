#pragma once

#include "Command/Parsing/Command.h"
#include "Util/Vector/Vector.h"

namespace Creep {
  struct Settings {
    static inline float2 creepConstants = float2(0);
    
    static void update(Command command);
    static void forward();
  };
};