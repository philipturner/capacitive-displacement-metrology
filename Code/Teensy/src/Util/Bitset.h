#pragma once

#include <stdint.h>

struct Bitset {
  static void printBinary(uint32_t input, uint8_t bitCount);
  static void printHex(uint32_t input, uint8_t digitCount);
};