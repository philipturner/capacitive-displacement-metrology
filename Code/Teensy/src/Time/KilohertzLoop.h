#pragma once

#include "Timestamp.h"
#include <inplace_function.h>
#include <IntervalTimer.h>

struct KilohertzLoop {
  static inline IntervalTimer timer;
  static inline teensy::inplace_function<void(void), 16> loopBody;
  static constexpr uint32_t period = 20;

  static inline Timestamp startTimestamp;
  static inline Timestamp previousTimestamp;
  static inline Timestamp latestTimestamp;
  static inline Timestamp integrationStartTimestamp;
  static inline uint32_t iterationID = 0;

  // An error is thrown when timing error >= limit specified below.
  static constexpr bool enableWarnings = true;
  static constexpr bool enableFatalErrors = true;
  static constexpr uint32_t differentialErrorWarning = 12;
  static constexpr uint32_t differentialErrorFatal = 20;
  static constexpr uint32_t integralErrorWarning = 16;
  static constexpr uint32_t integralErrorFatal = 38;

  // Function to execute reliably with a consistent time
  // base in the multiple kHz band.
  static void initialize(
    teensy::inplace_function<void(void), 16> loopBody);

  static void _kilohertzLoopBodyInner();

  static void throwError(
    const char *cString, 
    int64_t number1,
    int64_t number2,
    int64_t number3);
};

constexpr uint32_t KilohertzLoopRound(uint32_t desired) {
  uint32_t output = desired;
  output += KilohertzLoop::period - 1;
  output /= KilohertzLoop::period;
  output *= KilohertzLoop::period;
  return output;
}
