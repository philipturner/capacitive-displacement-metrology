#pragma once

#include "CommandTracker.h"

struct CommandParsing {
  static bool parseModeCode(
    uint32_t length,
    uint32_t &modeCode,
    uint32_t &remainderOffset);
  
  static bool checkAlphaCode(Command command);

  static bool parseAttributes(
    const char *stringBuffer,
    uint32_t stringLength,
    float *attributes,
    uint32_t &numAttributes);
};