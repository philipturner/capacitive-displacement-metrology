#include "../Util/Bitset.h"
#include "../Util/CRC.h"
#include "DAC.h"

void transferDAC2(uint8_t byte0, uint8_t byte1, uint8_t byte2, bool useCRC) {
  uint8_t bytes[4];
  bytes[0] = byte0;
  bytes[1] = byte1;
  bytes[2] = byte2;
  bytes[3] = CRC_calculate(bytes, 0x00);

  Serial.println();

  Serial.print("input: ");
  for (uint32_t i = 0; i < 4; ++i) {
    Bitset::printBinary(bytes[i], 8);
    Serial.print(" ");
  }
  Serial.println();

  // SPI_MODE0, FSDO = 1
  //
  // 5 Mbps - output works, input does
  // 15 Mbps - output works, input does, undefined behavior one time
  // 16 Mbps - undefined behavior all times
  // 34 Mbps - output works, input does not

  // SPI_MODE1, FSDO = 0
  //
  // 15 Mbps - output works, input does
  // 16 Mbps - output works, input does
  // 17 Mbps - output works, input does
  // 18 Mbps - output works, input does not
  // 20 Mbps - output works, input does not
  // 34 Mbps - output works, input does not

  // SPI_MODE1, FSDO = 1
  //
  // 15 Mbps - output works, input does
  // 30 Mbps - output works, input does
  // 34 Mbps - output works, input does
  // 35 Mbps - output works, input does not

  // SPI_MODE2, FSDO = 0
  //
  // 5 Mbps  - output works, input does
  // 14 Mbps - output works, input does
  // 15 Mbps - output works, input does
  // 16 Mbps - output works, input does not
  // 18 Mbps - output works, input does not
  // 19 Mbps - output works, input does not
  // 20 Mbps - output works, input does not
  // 40 Mbps - output works, input does not
  //
  // SPI_MODE2, FSDO = 1
  //
  // 5 Mbps - output works, input does
  // 14 Mbps - output works, input does
  // 16 Mbps - output works, input does
  // 20 Mbps - output works, input does
  // 30 Mbps - output works, input does
  // 32 Mbps - output works, input does
  // 33 Mbps - output works, input does
  // 34 Mbps - output works, input does
  // 35 Mbps - output works, input does not
  // 36 Mbps - output works, input does not
  // 40 Mbps - output works, input does not
  SPI.beginTransaction(SPISettings(5 * 1000000, MSBFIRST, SPI_MODE2));
  digitalWrite(CS_DAC2, 0);

  if (useCRC) {
    SPI.transfer(bytes, 4);
  } else {
    SPI.transfer(bytes, 3);
  }

  digitalWrite(CS_DAC2, 1);
  SPI.endTransaction();

  Serial.print("output: ");
  for (uint32_t i = 0; i < 4; ++i) {
    Bitset::printBinary(bytes[i], 8);
    Serial.print(" ");
  }
  Serial.println();

  uint32_t deviceID = 0;
  deviceID |= uint32_t(bytes[1]) << 8;
  deviceID |= uint32_t(bytes[2]);

  Serial.print("device ID: ");
  Serial.println(deviceID >> 2);

  Serial.print("CRC error: ");
  Serial.println(bytes[0] & 0b01000000);

  Serial.print("CRC MISO code: ");
  Bitset::printBinary(bytes[3], 8);
  Serial.println();

  // Is the algorithm correct?

  bytes[3] = CRC_calculate(bytes, bytes[3]);

  Serial.print("output: ");
  for (uint32_t i = 0; i < 4; ++i) {
    Bitset::printBinary(bytes[i], 8);
    Serial.print(" ");
  }
  Serial.println();

  bytes[3] = CRC_calculate(bytes, 0);

  Serial.print("output: ");
  for (uint32_t i = 0; i < 4; ++i) {
    Bitset::printBinary(bytes[i], 8);
    Serial.print(" ");
  }
  Serial.println();
}

/*
input: 0b00000100 0b00000000 0b00000000 0b01000011 
output: 0b11000000 0b00000011 0b00000000 0b01001011 

input: 0b00001010 0b00000000 0b00000101 0b01110110 
output: 0b11001001 0b11111111 0b11111110 0b00010001 
device ID: 16383
CRC error: 64
CRC MISO code: 0b00010001
output: 0b11001001 0b11111111 0b11111110 0b01001010 
*/

// Investigate DAC1 next, find its SPI limits.