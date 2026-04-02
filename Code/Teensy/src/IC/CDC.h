#pragma once

#include <i2c_device.h>

// register addresses
#define AD7745_STATUS        0x00
#define AD7745_CAP_DATA      0x01
#define AD7745_VT_DATA       0x04
#define AD7745_CAP_SETUP     0x07
#define AD7745_VT_SETUP      0x08
#define AD7745_EXC_SETUP     0x09
#define AD7745_CONFIGURATION 0x0A
#define AD7745_CAP_DAC_A     0x0B
#define AD7745_CAP_DAC_B     0x0C
#define AD7745_CAP_OFFSET    0x0D
#define AD7745_CAP_GAIN      0x0F
#define AD7745_VOLT_GAIN     0x11

// voltage/temperature modes
#define AD7745_VTMD_INTERNAL_TEMP 0b00
#define AD7745_VTMD_EXTERNAL_TEMP 0b01
#define AD7745_VTMD_VDD_MONITOR   0b10
#define AD7745_VTMD_EXTERNAL_VIN  0b11

// modes of operation
#define AD7745_MD_IDLE            0b000
#define AD7745_MD_CONTINUOUS_CONV 0b001
#define AD7745_MD_SINGLE_CONV     0b010
#define AD7745_MD_POWER_DOWN      0b011
#define AD7745_MD_OFFSET_CAL      0b101
#define AD7745_MD_GAIN_CAL        0b110

struct CDC {
  static inline I2CMaster& master = Master;
  static inline I2CDevice sensor = I2CDevice(master, 0x48, _BIG_ENDIAN);

  static void writeRegister(uint8_t registerAddress, uint8_t value);
  static uint8_t readRegister(uint8_t registerAddress);

  // Capacitance in pF.
  static float readCapacitance();

  // Temperature in °C.
  //
  // Notes: chip's self-heating raises its temperature about 0.5°C above
  // the PCB.
  static float readTemperature();

  // Voltage on the power pin.
  //
  // Notes: supply voltage is attenuated by a factor of 5.97.
  static float readSupplyVoltage();

  static void writeCapacitanceSetup(bool enabled, bool chop);
  static void writeVoltageSetup(bool enabled, uint8_t mode);
  static void writeConfiguration(uint8_t mode);
  static void writeCAPDAC(bool enabled, uint8_t code);

  static void check(bool transactionResult);
  static float decodeCapacitance(uint8_t bytes[3]);
  static float decodeTemperature(uint8_t bytes[3]);
  static float decodeVoltage(uint8_t bytes[3]);

  // Offset when the CAPDAC is on. The zero-code offset is not zero, so it
  // matters whether the CAPDAC is on or off.
  //
  // Error in the linear regression approximation: up to 20 fF.
  static float capdacOffset(uint8_t code);
};