#pragma once

#include <stdint.h>

struct Log {
  static constexpr uint32_t logPeriod = 48;
  static constexpr uint32_t logSize = 6000;
  static constexpr uint32_t messageLength = 27;
  static inline float valuesBuffer[logSize * 5];
  static inline uint8_t flagsBuffer[logSize];

  // Mark special messages with a flag, but do not alter the ordering. This
  // makes it easier to detect corrupted data transmission. Instead, the
  // PC must track time by starting at 0 and skipping special messages.
  static inline uint32_t transmittedLogID = 0;
  static inline uint32_t unsafeBufferedLogID = 0;

  static void transmitBufferedSamples();

  static void throwError(
    const char *cString, 
    int32_t number1,
    int32_t number2,
    int32_t number3);
  
  static void writeValues(
    float lane0 = 0,
    float lane1 = 0,
    float lane2 = 0,
    float lane3 = 0,
    float lane4 = 0,
    uint8_t flags = 0);
};