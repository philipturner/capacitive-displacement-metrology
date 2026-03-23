#pragma once

#include <stdint.h>

struct KilohertzLoop {
  static inline IntervalTimer timer;
  static inline teensy::inplace_function<void(void), 16> loopBody;
  static inline uint32_t period;

  // Prevents data races when external code reads output of
  // high-frequency code, and may be interrupted by that
  // high-frequency code's interval timer.
  static inline bool lock;

  // These will roll back to zero after 71 minutes. However, if we
  // check for and handle a rollover event, the loop can run forever.
  static inline uint32_t startTimestamp;
  static inline uint32_t previousTimestamp;
  static inline uint32_t latestTimestamp;

  // Function to execute reliably with a consistent time
  // base in the multiple kHz band.
  //
  // Time fidelity: close to program startup, a few jumps
  // can be larger or smaller than the expected duration.
  static void initialize(
    teensy::inplace_function<void(void), 16> loopBody,
    uint32_t period);
};
