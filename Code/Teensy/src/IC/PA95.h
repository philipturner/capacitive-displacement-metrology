#pragma once

#include <stdint.h>

// Maximum slew rate:
// 18.6 V/μs (positive)
// -20.6 V/μs (negative)
//
// Expected: 30.0 V/μs
//
// This is not variation within a batch; all three op amps have
// the number above, to within 0.2 V/μs. Perhaps the culprit is using
// a 10 pF compensation capacitor instead of 4.7 pF recommended on
// the data sheet. It will be very hard or impossible to desolder
// the existing capacitors, now that all three op amps are installed.
struct PA95 {
  // DAC channel -> output channel mapping
  // gain and offset constants for each output channel
  static void writeVoltage(uint8_t channelID, float voltage);
};