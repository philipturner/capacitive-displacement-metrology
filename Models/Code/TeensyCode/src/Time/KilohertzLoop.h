#pragma once

#include <stdint.h>

// Function to execute reliably with a consistent time
// base in the multiple kHz band.
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

// WARNING: Initialize this during setup.
// WARNING: After 1.2 hours, the 32-bit integers will overflow.
inline uint32_t startTimestamp;
inline uint32_t latestTimestamp;
inline uint32_t oscilloscopeTimestamp;
inline bool oscilloscopeLock = false;