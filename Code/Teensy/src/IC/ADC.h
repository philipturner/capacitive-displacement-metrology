#pragma once

#include <SPI.h>

inline uint8_t CS_ADC = 10;

// register addresses
#define ADS8699_DEVICE_ID_REG   0x00
#define ADS8699_RST_PWRCTL_REG  0x04
#define ADS8699_SDI_CTL_REG     0x08
#define ADS8699_SDO_CTL_REG     0x0C
#define ADS8699_DATAOUT_CTL_REG 0x10
#define ADS8699_RANGE_SEL_REG   0x14
#define ADS8699_ALARM_REG       0x20
#define ADS8699_ALARM_H_TH_REG  0x24
#define ADS8699_ALARM_L_TH_REG  0x28

// SPI commands
#define ADS8699_NOP         0b0000000
#define ADS8699_CLEAR_HWORD 0b1100000
#define ADS8699_READ_HWORD  0b1100100
#define ADS8699_READ        0b0100100
#define ADS8699_WRITE_FULL  0b1101000 // write 16 bits to register
#define ADS8699_WRITE_MS    0b1101001
#define ADS8699_WRITE_LS    0b1101010

struct ADCInput {
  uint8_t command;
  uint8_t registerAddress;
  uint16_t data;
};

struct ADCOutputHWORD {
  uint16_t data;

  ADCOutputHWORD(uint32_t rawData) {
    data = rawData >> 16;
  }
};

struct ADCOutputConversion {
  // Fractional value from 0.0 to 1.0 full-scale.
  float floatValue;
  uint32_t integerValue;
  uint32_t otherBits;

  ADCOutputConversion(uint32_t rawData) {
    uint32_t integer18Bit = rawData >> 14;
    uint32_t denominator = 1 << 18;
    floatValue = float(integer18Bit) / float(denominator);
    integerValue = integer18Bit;
    otherBits = rawData & 0x3FFF;
  }

  // Requires:
  // ADC::writeRegister(ADS8699_DATAOUT_CTL_REG, 0x4000 | 0b1000);
  // ADC::writeRegister(ADS8699_DEVICE_ID_REG + 2, 0b1101);
  bool checkParity(uint8_t deviceID) {
    if ((otherBits >> 10) != deviceID) {
      return false;
    }

    uint32_t codeCount = __builtin_popcount(integerValue);
    uint32_t idCount = __builtin_popcount(uint32_t(deviceID));
    uint32_t parity1 = codeCount + ((otherBits >> 9) & 1);
    uint32_t parity2 = codeCount + idCount + ((otherBits >> 8) & 1);

    if ((parity1 & 1) != 0) {
      return false;
    }
    if ((parity2 & 1) != 0) {
      return false;
    }
    return true;
  }
};

struct ADC {
  static uint32_t transfer(ADCInput input, uint32_t speed = 18000000);

  static void nop();

  static ADCOutputConversion readConversionResult(uint32_t speed = 18000000);
  
  // Write the 16 lowest bits of the register.
  static void writeRegister(uint8_t registerAddress, uint16_t data);

  // Read the full 32-bit register.
  static uint32_t readRegister(uint8_t registerAddress);

  // 'c' received - ADC performs a measurement
  // 'd' received - ADC reports contents of ADS8699_SDI_CTL_REG
  // '0' received - ADC (but not Teensy) switches to SPI_MODE0
  // '1' received - ADC (but not Teensy) switches to SPI_MODE1
  // '2' received - ADC (but not Teensy) switches to SPI_MODE2
  // '3' received - ADC (but not Teensy) switches to SPI_MODE3
  static void responsivenessDiagnosticLoop();
};