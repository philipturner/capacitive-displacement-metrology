#pragma once

#include <SPI.h>

constexpr uint8_t CS_ADC = 10;

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

// range codes
#define ADS8699_RANGE_12V_BIPOLAR  0b0000
#define ADS8699_RANGE_10V_BIPOLAR  0b0001
#define ADS8699_RANGE_6V_BIPOLAR   0b0010
#define ADS8699_RANGE_5V_BIPOLAR   0b0011
#define ADS8699_RANGE_2V5_BIPOLAR  0b0100
#define ADS8699_RANGE_12V_UNIPOLAR 0b1000
#define ADS8699_RANGE_10V_UNIPOLAR 0b1001
#define ADS8699_RANGE_6V_UNIPOLAR  0b1010
#define ADS8699_RANGE_5V_UNIPOLAR  0b1011

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
  float voltage;
  uint32_t integerValue;
  uint32_t otherBits;

  // Requires that range code is 0b0000.
  ADCOutputConversion(uint32_t rawData);

  // Requires:
  // ADC::writeRegister(ADS8699_DATAOUT_CTL_REG, 0x4000 | 0b1000);
  // ADC::writeRegister(ADS8699_DEVICE_ID_REG + 2, 0b1101);
  bool checkParity(uint8_t deviceID);
};

struct ADC {
  static uint32_t transfer(ADCInput input);

  static void nop();

  static ADCOutputConversion readVoltage();
  
  // Write the 16 lowest bits of the register.
  static void writeRegister(uint8_t registerAddress, uint16_t data);

  // Read the full 32-bit register.
  static uint32_t readRegister(uint8_t registerAddress);
};