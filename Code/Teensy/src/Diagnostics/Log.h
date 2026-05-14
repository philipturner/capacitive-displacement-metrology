#pragma once

#include <stdint.h>

struct Log {
  static constexpr uint32_t targetLogPeriod = 50;
  static constexpr uint32_t logSize = 12000;
  static inline float ringBuffers[4][logSize];

  static inline uint32_t transmittedLogID;
  static inline uint32_t unsafeBufferedLogID;
  static inline uint32_t errorCode;

  static void initialize();

  static void transmitBufferedSamples();
};