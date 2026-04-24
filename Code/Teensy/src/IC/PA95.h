#pragma once

#include <stdint.h>

// DAC channel -> output channel mapping
// gain and offset constants for each output channel

struct PA95 {
  static void writeVoltage(uint8_t channelID, float voltage);
};