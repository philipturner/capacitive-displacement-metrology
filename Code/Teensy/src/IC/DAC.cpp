#include "DAC.h"

uint16_t DAC::transfer(
  uint8_t CS,
  DACInput input,
  CRC::Flags flags
) {
  if (!CRC::isValidConfig(flags)) {
    Serial.println("Invalid CRC setup.");
    exit(0);
  }

  uint8_t bytes[4];
  bytes[0] = (input.command << 7) | input.registerAddress;
  bytes[1] = input.data >> 8;
  bytes[2] = input.data & 0xFF;
  if (enableCRC && uint8_t(flags & CRC::Flags::MOSI) != 0) {
    bytes[3] = CRC::calculate(bytes);
  }
  
  // DAC81401, SPI_MODE0, FSDO = 1 | 5 Mbps
  // DAC81401, SPI_MODE1, FSDO = 0 | 17-18 Mbps
  // DAC81401, SPI_MODE1, FSDO = 1 | 34-35 Mbps
  // DAC81401, SPI_MODE2, FSDO = 0 | 15-16 Mbps
  // DAC81401, SPI_MODE2, FSDO = 1 | 34-35 Mbps
  // DAC81404, SPI_MODE2, FSDO = 1 | 34-35 Mbps
  SPI.beginTransaction(SPISettings(34 * 1000000, MSBFIRST, SPI_MODE2));
  digitalWrite(CS, 0);
  if (enableCRC && uint8_t(flags & CRC::Flags::MOSI) != 0) {
    SPI.transfer(bytes, 4);
  } else {
    SPI.transfer(bytes, 3);
  }
  digitalWrite(CS, 1);
  SPI.endTransaction();

  if (enableCRC && uint8_t(flags & CRC::Flags::MISO_FLAG) != 0) {
    uint8_t errorBit = bytes[0] & 0b01000000;
    if (errorBit) {
      Serial.println("DAC MOSI data was corrupted.");
      exit(0);
    }
  }

  if (enableCRC && uint8_t(flags & CRC::Flags::MISO_VALIDITY) != 0) {
    uint8_t misoCode = bytes[3];
    uint8_t expectedMisoCode = CRC::calculate(bytes);
    uint8_t zeroMisoCode = CRC::calculate(bytes, misoCode);

    if (expectedMisoCode != misoCode || zeroMisoCode != 0) {
      Serial.println("DAC MISO data was corrupted.");
      exit(0);
    }
  }

  uint16_t output = 0;
  if (uint8_t(flags & CRC::Flags::MISO_VALIDITY)) {
    output |= uint16_t(bytes[1]) << 8;
    output |= uint16_t(bytes[2]);
  }
  return output;
}

void DAC::writeRegister(
  uint8_t CS,
  uint8_t registerAddress, 
  uint16_t data, 
  CRC::Flags flags
) {
  DACInput input;
  input.command = DAC81404_WRITE;
  input.registerAddress = registerAddress;
  input.data = data;
  transfer(CS, input, flags);
}

void DAC::writeVoltage(
  uint8_t CS,
  uint8_t channelID,
  float voltage
) {
  float floatValue = (voltage + 12) / 24;

  uint16_t integerValue;
  if (floatValue <= 0) {
    integerValue = 0;
  } else if (floatValue >= 1) {
    integerValue = UINT16_MAX;
  } else {
    integerValue = uint16_t(floatValue * float(1 << 16));
  }

  uint8_t registerAddress = DAC81404_DACA + channelID;
  CRC::Flags flags = CRC::Flags::MOSI | CRC::Flags::MISO_FLAG;
  writeRegister(CS, registerAddress, integerValue, flags);
}

// Data transfer process:
//
// frame 0 | input read data | output ignored
// frame 1 | write to NOP    | output receive data
uint16_t DAC::readRegister(
  uint8_t CS,
  uint8_t registerAddress
) {
  // frame 0
  {
    DACInput input;
    input.command = DAC81404_READ;
    input.registerAddress = registerAddress;
    
    CRC::Flags flags = CRC::Flags::MOSI | CRC::Flags::MISO_FLAG;
    transfer(CS, input, flags);
  }

  // frame 1
  {
    DACInput input;
    input.command = DAC81404_WRITE;
    input.registerAddress = DAC81404_NOP;
    input.data = 0x0000;

    CRC::Flags flags = 
    CRC::Flags::MOSI | CRC::Flags::MISO_FLAG | CRC::Flags::MISO_VALIDITY;
    return transfer(CS, input, flags);
  }
}