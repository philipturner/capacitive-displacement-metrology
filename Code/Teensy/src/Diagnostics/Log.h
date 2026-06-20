#pragma once

#include "Time/KilohertzLoop.h"

struct Log {
  enum class Flags: uint8_t {
    modeChange = 0,
    kilohertzLoopWarning = 1,
    history = 2,
    historyDiscard = 3,
    spectroscopy = 4,
    imaging = 5,
    imagingSettings = 6,
    creepSettings = 7,
    tiltCalculation = 8,
    tiltSettings = 9,
  };

  static constexpr uint32_t logPeriod = KilohertzLoopRound(80);
  static constexpr uint32_t logSize = 16384;

  // Mark special messages with a flag, but do not alter the ordering. This
  // makes it easier to detect corrupted data transmission. Instead, the
  // PC must track time by starting at 0 and skipping special messages.
  static inline uint64_t transmittedLogID = 0;
  static inline uint64_t unsafeBufferedLogID = 0;

  static void reset();

  static void transmitBufferedSamples();

  static void throwError(
    const char *cString, 
    int64_t number1,
    int64_t number2,
    int64_t number3);

  static float encodeRawBits(uint32_t bits);
  
  static void write(
    Flags flags,
    float lane0 = 0,
    float lane1 = 0,
    float lane2 = 0,
    float lane3 = 0,
    float lane4 = 0);
};