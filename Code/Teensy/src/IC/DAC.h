#pragma once

#include "../Util/CRC.h"
#include <SPI.h>

inline uint8_t CS_DAC1 = 36;
inline uint8_t CS_DAC2 = 37;

// register addresses
#define DAC81404_NOP       0x00
#define DAC81404_DEVICEID  0x01
#define DAC81404_STATUS    0x02
#define DAC81404_SPICONFIG 0x03
#define DAC81404_GENCONFIG 0x04
#define DAC81404_DACPWDWN  0x09
#define DAC81404_DACRANGE  0x0A
#define DAC81404_TRIGGER   0x0E
#define DAC81404_DACA      0x10
#define DAC81404_DACB      0x11
#define DAC81404_DACC      0x12
#define DAC81404_DACD      0x13

// SPI commands
#define DAC81404_WRITE 0
#define DAC81404_READ  1

void transferDAC2(
  uint8_t byte0, 
  uint8_t byte1, 
  uint8_t byte2, 
  CRC::Flags flags = CRC::Flags::MOSI | CRC::Flags::MISO_FLAG);