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
  if (uint8_t(flags & CRC::Flags::MOSI)) {
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
  if (uint8_t(flags & CRC::Flags::MOSI)) {
    SPI.transfer(bytes, 4);
  } else {
    SPI.transfer(bytes, 3);
  }
  digitalWrite(CS, 1);
  SPI.endTransaction();

  if (uint8_t(flags & CRC::Flags::MISO_FLAG)) {
    uint8_t errorBit = bytes[0] & 0b01000000;
    if (errorBit) {
      Serial.println("DAC MOSI data was corrupted.");
      exit(0);
    }
  }

  if (uint8_t(flags & CRC::Flags::MISO_VALIDITY)) {
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

/*
void ADC::nop() {
  ADCInput input;
  input.command = ADS8699_NOP;
  input.registerAddress = 0;
  input.data = 0;
  transfer(input);
}

ADCOutputConversion ADC::readVoltage() {
  ADCInput input;
  input.command = ADS8699_NOP;
  input.registerAddress = 0;
  input.data = 0;
  uint32_t rawData = transfer(input);

  ADCOutputConversion output(rawData);
  return output;
}

void ADC::writeRegister(uint8_t registerAddress, uint16_t data) {
  ADCInput input;
  input.command = ADS8699_WRITE_FULL;
  input.registerAddress = registerAddress;
  input.data = uint16_t(data);
  transfer(input);
}
*/

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
  float floatValue
) {
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
  DAC::writeRegister(CS, registerAddress, integerValue, flags);
}