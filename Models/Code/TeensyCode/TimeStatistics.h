#pragma once

struct TimeStatistics {
  uint32_t above1000000us_jumps = 0;
  uint32_t above100000us_jumps = 0;
  uint32_t above10000us_jumps = 0;
  uint32_t above1000us_jumps = 0;
  uint32_t above100us_jumps = 0;
  uint32_t above20us_jumps = 0;
  uint32_t exactly20us_jumps = 0;
  uint32_t under20us_jumps = 0;
  uint32_t total_jumps = 0;

  void integrate(uint32_t jumpDuration);
};

TimeStatistics timeStatistics;

// WARNING: Initialize this during setup.
// WARNING: After 1.2 hours, the 32-bit integers will overflow.
uint32_t startTimestamp;
uint32_t latestTimestamp;
uint32_t oscilloscopeTimestamp;
bool oscilloscopeLock = false;