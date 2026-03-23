#include "DAC.h"

void transferDAC2(uint8_t byte0, uint8_t byte1, uint8_t byte2) {
  uint8_t bytes[3];
  bytes[0] = byte0;
  bytes[1] = byte1;
  bytes[2] = byte2;

  SPI.beginTransaction(SPISettings(5 * 1000000, MSBFIRST, SPI_MODE2));
  digitalWrite(CS_DAC2, 0);
  SPI.transfer(bytes, 3);
  digitalWrite(CS_DAC2, 1);
  SPI.endTransaction();

  uint32_t deviceID = 0;
  deviceID |= uint32_t(bytes[1]) << 8;
  deviceID |= uint32_t(bytes[2]);

  Serial.print(deviceID);
  Serial.print(" ");
  Serial.print(deviceID >> 2);
  Serial.println();
}