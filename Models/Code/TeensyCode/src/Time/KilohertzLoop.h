#pragma once

#include <stdint.h>

namespace KilohertzLoop {
  inline IntervalTimer timer;

  inline uint32_t startTimestamp;
  inline uint32_t latestTimestamp;
  inline bool lock = false;
};

// Function to execute reliably with a consistent time
// base in the multiple kHz band.
//
// Time fidelity: close to program startup, a few jumps
// can be larger or smaller than the expected duration.
//
// ## Usage
//
// startTimestamp = micros();
// latestTimestamp = startTimestamp;
// oscilloscopeTimestamp = startTimestamp;
// timer.begin(kilohertzLoop, 20);
//
// 20 kHz (50 μs) when SPI rate reduced to 5 MHz
// 50 kHz (20 μs) otherwise
void kilohertzLoop();

// Implement this in the top-level script.
void kilohertzLoopBody(uint32_t previousTimestamp);