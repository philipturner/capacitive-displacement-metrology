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

  static void writeCapacitanceSetup(bool enabled);
  static void writeVoltageSetup(bool enabled, uint8_t mode);
  static void writeConfiguration(uint8_t mode);
  static void writeCAPDAC(bool enabled, uint8_t code);

  static void check(bool transactionResult);
  static float decodeCapacitance(uint8_t bytes[3]);
  static float decodeTemperature(uint8_t bytes[3]);
  static float decodeVoltage(uint8_t bytes[3]);
};