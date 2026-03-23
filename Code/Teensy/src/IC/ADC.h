#pragma once

#include <SPI.h>

inline uint8_t CS_ADC = 10;

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
  static uint32_t transfer(ADCInput input, uint32_t speed = 15000000);

  static void nop();

  static float readConversionCode();
  
  // Write the 16 lowest bits of the register.
  static void writeRegister(uint8_t registerAddress, uint16_t data);

  // Read the full 32-bit register.
  static uint32_t readRegister(uint8_t registerAddress);

  // 'c' received - ADC performs a measurement
  // 'd' received - ADC reports contents of ADS8689_SDI_CTL_REG
  // '0' received - ADC and Teensy code switch to SPI_MODE0
  // '1' received - ADC and Teensy code switch to SPI_MODE1
  // '2' received - ADC and Teensy code switch to SPI_MODE2
  // '3' received - ADC and Teensy code switch to SPI_MODE3
  static inline uint8_t spiMode = SPI_MODE0;
  static inline uint32_t conversionSpeed = 15 * 1000000;
  static void responsivenessDiagnosticLoop();
};