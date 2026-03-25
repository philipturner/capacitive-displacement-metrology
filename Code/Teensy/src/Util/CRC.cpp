#include "CRC.h"

uint8_t CRC::calculate(const uint8_t bytes[], uint8_t seed) {
  uint32_t polynomial = 0x107;

  uint32_t input = 0;
  input |= bytes[0] << 24;
  input |= bytes[1] << 16;
  input |= bytes[2] << 8;
  input |= seed;

  // Takes <1 microsecond in its current form; no need to optimize.
  for (int32_t shiftAmount = 23; shiftAmount >= 0; --shiftAmount) {
    uint32_t inputOneMask = 0x100 << shiftAmount;
    uint32_t shiftedPolynomial = polynomial << shiftAmount;

    uint32_t inputIsOne = input & inputOneMask;
    if (!inputIsOne) {
      shiftedPolynomial = 0;
    }
    
    input ^= shiftedPolynomial;
  }

  return uint8_t(input);
}