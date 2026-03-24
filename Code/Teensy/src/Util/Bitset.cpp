#include <Arduino.h>
#include "Bitset.h"

void Bitset::print(uint32_t input, uint8_t bitCount) {
  Serial.print("0b");

  for (int8_t bitID = bitCount - 1; bitID >= 0; --bitID) {
    uint32_t mask = 1 << uint32_t(bitID);
    uint32_t maskedInput = input & mask;
    maskedInput >>= uint32_t(bitID);

    Serial.print(maskedInput);
  }
}