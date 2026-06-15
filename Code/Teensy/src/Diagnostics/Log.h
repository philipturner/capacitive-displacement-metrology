#pragma once

#include "Time/KilohertzLoop.h"

struct Log {
  static constexpr uint32_t logPeriod = KilohertzLoopRound(64);
  static constexpr uint32_t logSize = 10000;

  // Mark special messages with a flag, but do not alter the ordering. This
  // makes it easier to detect corrupted data transmission. Instead, the
  // PC must track time by starting at 0 and skipping special messages.
  static inline uint32_t transmittedLogID = 0;
  static inline uint32_t unsafeBufferedLogID = 0;

  static void reset();

  static void transmitBufferedSamples();

  static void throwError(
    const char *cString, 
    int32_t number1,
    int32_t number2,
    int32_t number3);
    
  static void writeValuesWithFlags(
    uint8_t flags,
    float lane0 = 0,
    float lane1 = 0,
    float lane2 = 0,
    float lane3 = 0,
    float lane4 = 0);

  static void writeValuesNormal(
    float lane0 = 0,
    float lane1 = 0,
    float lane2 = 0,
    float lane3 = 0,
    float lane4 = 0
  ) {
    writeValuesWithFlags(
      0,
      lane0,
      lane1,
      lane2,
      lane3,
      lane4);
  }
};