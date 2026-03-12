#pragma once

#include <SPI.h>

uint8_t CS_ADC = 10;

/* Input Shift Register Commands for ADS8689 */
#define ADS8689_DEVICE_ID_REG   0x00
#define ADS8689_RST_PWRCTL_REG  0x04
#define ADS8689_SDI_CTL_REG     0x08
#define ADS8689_SDO_CTL_REG     0x0C
#define ADS8689_DATAOUT_CTL_REG 0x10
#define ADS8689_RANGE_SEL_REG   0x14
#define ADS8689_ALARM_REG       0x20
#define ADS8689_ALARM_H_TH_REG  0x24
#define ADS8689_ALARM_L_TH_REG  0x28

// SPI commands
#define ADS8689_NOP         0b0000000
#define ADS8689_CLEAR_HWORD 0b1100000
#define ADS8689_READ_HWORD  0b1100100
#define ADS8689_READ        0b0100100
#define ADS8689_WRITE_FULL  0b1101000 //write 16 bits to register
#define ADS8689_WRITE_MS    0b1101001
#define ADS8689_WRITE_LS    0b1101010

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
  float data;

  ADCOutputConversion(uint32_t rawData) {
    uint32_t integer18Bit = rawData >> 14;
    uint32_t denominator = 1 << 18;
    data = float(integer18Bit) / float(denominator);
  }
};

struct ADC {
  static uint32_t transfer(ADCInput input, uint32_t speed = 15 * 1000000);

  static void nop();

  static float readConversionCode();

  // Legend
  //
  // range 0b0000 | -12.288 V to 12.288 V
  // range 0b0001 | -10.24 V to 10.24 V
  // range 0b0010 | -6.144 V to 6.144 V
  // range 0b0011 | -5.12 V to 5.12 V
  // range 0b0100 | -2.56 V to 2.56 V
  // range 0b1000 | 0 V to 12.288 V
  // range 0b1001 | 0 V to 10.24 V
  // range 0b1010 | 0 V to 6.144 V
  // range 0b1011 | 0 V to 5.12 V
  static void writeRangeSelect(uint8_t rangeCode);

  static uint32_t readRangeSelect();
};