#pragma once

#include <stdint.h>

struct Bitset {
  static void printBinary(uint32_t input, uint8_t bitCount);
  static void printHex(uint32_t input, uint8_t digitCount);
};

uint8_t CRC_calculate(const uint8_t bytes[], uint8_t seed);