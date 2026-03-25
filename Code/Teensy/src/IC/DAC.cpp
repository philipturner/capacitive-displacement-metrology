#include "../Util/Bitset.h"
#include "DAC.h"

void transferDAC2(uint8_t byte0, uint8_t byte1, uint8_t byte2, CRC::Flags flags) {
  
  uint8_t bytes[4];
  bytes[0] = byte0;
  bytes[1] = byte1;
  bytes[2] = byte2;
  if (uint8_t(flags & CRC::Flags::MOSI)) {
    bytes[3] = CRC::calculate(bytes);
  }
  
  // DAC81401, SPI_MODE0, FSDO = 1
  //
  // 5 Mbps - output works, input does
  // 15 Mbps - output works, input does, undefined behavior one time
  // 16 Mbps - undefined behavior all times
  // 34 Mbps - output works, input does not
  //
  // For the remaining configs, the point where input (MISO) stops working.
  //
  // DAC81401, SPI_MODE1, FSDO = 0 | 17-18 Mbps
  // DAC81401, SPI_MODE1, FSDO = 1 | 34-35 Mbps
  // DAC81401, SPI_MODE2, FSDO = 0 | 15-16 Mbps
  // DAC81401, SPI_MODE2, FSDO = 1 | 34-35 Mbps
  // DAC81404, SPI_MODE2, FSDO = 1 | 34-35 Mbps

  SPI.beginTransaction(SPISettings(34 * 1000000, MSBFIRST, SPI_MODE2));
  digitalWrite(CS_DAC1, 0);

  if (useCRC) {
    SPI.transfer(bytes, 4);
  } else {
    SPI.transfer(bytes, 3);
  }

  digitalWrite(CS_DAC1, 1);
  SPI.endTransaction();

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