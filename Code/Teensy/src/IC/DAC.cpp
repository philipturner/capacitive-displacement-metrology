#include "../Util/CRC.h"
#include "DAC.h"

void transferDAC2(uint8_t byte0, uint8_t byte1, uint8_t byte2) {
  uint8_t bytes[4];
  bytes[0] = byte0;
  bytes[1] = byte1;
  bytes[2] = byte2;
  bytes[3] = 0;

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
  SPI.transfer(bytes, 3);
  digitalWrite(CS_DAC2, 1);
  SPI.endTransaction();

  uint32_t deviceID = 0;
  deviceID |= uint32_t(bytes[1]) << 8;
  deviceID |= uint32_t(bytes[2]);

  Serial.print("CRC error: ");
  Serial.println(bytes[0] & 0b01000000);

  Serial.print("device ID: ");
  Serial.println(deviceID >> 2);

  Serial.print("CRC MISO code: ");
  Serial.println(bytes[3]);
  
  Serial.println();
}

// Investigate DAC1 next, find its SPI limits.