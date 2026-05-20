#pragma once

#include <inplace_function.h>
#include <IntervalTimer.h>

struct KilohertzLoop {
  static inline IntervalTimer timer;
  static inline teensy::inplace_function<void(void), 16> loopBody;
  static inline uint32_t period;

  // These will roll back to zero after 71 minutes. However, if we
  // check for and handle a rollover event, the loop can run forever.
  static inline uint32_t startTimestamp;
  static inline uint32_t previousTimestamp;
  static inline uint32_t latestTimestamp;
  static inline uint32_t integrationStartTimestamp = 0;
  static inline uint32_t iterationID = 0;

  // Function to execute reliably with a consistent time
  // base in the multiple kHz band.
  //
  // Time fidelity: close to program startup, a few jumps
  // can be larger or smaller than the expected duration.
  static void initialize(
    teensy::inplace_function<void(void), 16> loopBody,
    uint32_t period);

  static void _kilohertzLoopBodyInner();

  static void throwError(
    const char *cString, 
    int32_t number1,
    int32_t number2,
    int32_t number3);
};
