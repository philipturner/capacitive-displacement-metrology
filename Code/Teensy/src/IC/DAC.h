#pragma once

#include "../Util/CRC.h"
#include <SPI.h>

constexpr uint8_t CS_DAC1 = 36;
constexpr uint8_t CS_DAC2 = 37;

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

struct DACInput {
  uint8_t command;
  uint8_t registerAddress;
  uint16_t data;
};

struct DAC {
  static uint16_t transfer(
    uint8_t CS,
    DACInput input,
    CRC::Flags flags);

  static void writeRegister(
    uint8_t CS,
    uint8_t registerAddress, 
    uint16_t data, 
    CRC::Flags flags);

  // Requires that range select is 0b1110.
  static void writeVoltage(
    uint8_t CS,
    uint8_t channelID,
    float voltage);

  static uint16_t readRegister(
    uint8_t CS,
    uint8_t registerAddress);
};

struct DAC1 {
  static void writeRegister(
    uint8_t registerAddress, 
    uint16_t data, 
    CRC::Flags flags = CRC::Flags::MOSI | CRC::Flags::MISO_FLAG
  ) {
    DAC::writeRegister(CS_DAC1, registerAddress, data, flags);
  }

  static void writeVoltage(uint8_t channelID, float voltage) {
    DAC::writeVoltage(CS_DAC1, channelID, voltage);
  }

  static uint16_t readRegister(uint8_t registerAddress) {
    return DAC::readRegister(CS_DAC1, registerAddress);
  }
};

struct DAC2 {
  static void writeRegister(
    uint8_t registerAddress, 
    uint16_t data, 
    CRC::Flags flags = CRC::Flags::MOSI | CRC::Flags::MISO_FLAG
  ) {
    DAC::writeRegister(CS_DAC2, registerAddress, data, flags);
  }

  static void writeVoltage(uint8_t channelID, float voltage) {
    DAC::writeVoltage(CS_DAC2, channelID, voltage);
  }

  static uint16_t readRegister(uint8_t registerAddress) {
    return DAC::readRegister(CS_DAC2, registerAddress);
  }
};