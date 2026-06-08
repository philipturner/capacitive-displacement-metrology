#pragma once

#include <stdint.h>

struct CommandParsing {
  static bool decodeAttributes(
    const char *stringBuffer,
    uint32_t stringLength,
    float *attributes,
    uint32_t &numAttributes);

  static int32_t findModeCode(
    uint32_t length,
    uint32_t &remainderOffset);
};