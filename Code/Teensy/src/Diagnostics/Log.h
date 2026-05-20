#pragma once

#include <stdint.h>

struct Log {
  static constexpr uint32_t targetLogPeriod = 50;
  static constexpr uint32_t logSize = 12000;
  static inline float ringBuffers[4][logSize];

  static inline uint32_t transmittedLogID;
  static inline uint32_t unsafeBufferedLogID;

  static void initialize();

  static void transmitBufferedSamples();

  static void throwError(
    const char *cString, 
    int32_t number1,
    int32_t number2,
    int32_t number3);
};