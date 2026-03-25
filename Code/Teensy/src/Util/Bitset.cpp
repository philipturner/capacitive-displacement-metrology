#include <Arduino.h>
#include "Bitset.h"

void Bitset::printBinary(uint32_t input, uint8_t bitCount) {
  Serial.print("0b");

  for (int8_t bitID = bitCount - 1; bitID >= 0; --bitID) {
    uint32_t mask = 1 << uint32_t(bitID);
    uint32_t maskedInput = input & mask;
    maskedInput >>= uint32_t(bitID);

    Serial.print(maskedInput);
  }
}

void Bitset::printHex(uint32_t input, uint8_t digitCount) {
    Serial.print("0x");

    for (int8_t digitID = digitCount - 1; digitID >= 0; --digitID) {
      uint32_t mask = 0xF << (uint32_t(digitID) * 4);
      uint32_t maskedInput = input & mask;
      maskedInput >>= uint32_t(digitID) * 4;

      if (maskedInput < 10) {
        Serial.print(maskedInput);
      } else if (maskedInput == 10) {
        Serial.print("A");
      } else if (maskedInput == 11) {
        Serial.print("B");
      } else if (maskedInput == 12) {
        Serial.print("C");
      } else if (maskedInput == 13) {
        Serial.print("D");
      } else if (maskedInput == 14) {
        Serial.print("E");
      } else if (maskedInput == 15) {
        Serial.print("F");
      }
    }
}
