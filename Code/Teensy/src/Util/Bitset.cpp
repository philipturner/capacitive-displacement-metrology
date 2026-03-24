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

uint8_t CRC_calculate(const uint8_t bytes[], uint8_t seed) {
  uint32_t startTime = micros();
  
  uint32_t polynomial = 0x107;

  uint32_t input = 0;
  input |= bytes[0] << 24;
  input |= bytes[1] << 16;
  input |= bytes[2] << 8;
  input |= seed;

  // Takes <1 microsecond in its current form; no need to optimize.
  for (int32_t shiftAmount = 23; shiftAmount >= 0; --shiftAmount) {
    //Bitset::printBinary(input, 32);
    //Serial.println();

    uint32_t inputOneMask = 0x100 << shiftAmount;
    //Bitset::printBinary(inputOneMask, 32);
    //Serial.println();

    uint32_t shiftedPolynomial = polynomial << shiftAmount;
    //Bitset::printBinary(shiftedPolynomial, 32);
    //Serial.println();

    uint32_t inputIsOne = input & inputOneMask;
    if (!inputIsOne) {
      shiftedPolynomial = 0;
    }
    input ^= shiftedPolynomial;
  }

  uint32_t endTime = micros();

  //Bitset::printBinary(input, 32);
  //Serial.println();

  Serial.print("latency: ");
  Serial.print(endTime - startTime);
  Serial.println();

  return uint8_t(input);
}