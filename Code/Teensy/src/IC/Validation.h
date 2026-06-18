#pragma once

#include "Util/Offline.h"

namespace IC {
  struct Validation {
    static constexpr bool enableCRC = false;
    static constexpr bool checkDeviceID = Offline::isOnline;
  };
};