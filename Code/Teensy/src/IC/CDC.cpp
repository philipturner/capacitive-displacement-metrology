#include "CDC.h"

void CDC::writeRegister(uint8_t registerAddress, uint8_t value) {
  check(sensor.write(registerAddress, value, true));
}

uint8_t CDC::readRegister(uint8_t registerAddress) {
  uint8_t value = 0;
  check(sensor.read(registerAddress, &value, true));
  return value;
}

float CDC::readCapacitance() {
  uint8_t data[3] = { 0, 0, 0 };
  check(sensor.read(AD7745_CAP_DATA, data, 3, true));
  return decodeCapacitance(data);
}

float CDC::readTemperature() {
  uint8_t data[3] = { 0, 0, 0 };
  check(sensor.read(AD7745_VT_DATA, data, 3, true));
  return decodeTemperature(data);
}

float CDC::readSupplyVoltage() {
  uint8_t data[3] = { 0, 0, 0 };
  check(sensor.read(AD7745_VT_DATA, data, 3, true));
  return decodeVoltage(data) * 5.97;
}

void CDC::writeCapacitanceSetup(bool enabled, bool chop) {
  uint8_t enabledFlag = enabled ? 0x80 : 0x00;
  uint8_t chopFlag = chop ? 0x01 : 0x00;
  writeRegister(AD7745_CAP_SETUP, enabledFlag | chopFlag);
}

void CDC::writeVoltageSetup(bool enabled, uint8_t mode) {
  uint8_t enabledFlag = enabled ? 0x80 : 0x00;
  uint8_t modeFlag = mode << 5;
  uint8_t chopFlag = 0x01;
  writeRegister(AD7745_VT_SETUP, enabledFlag | modeFlag | chopFlag);
}

void CDC::writeConfiguration(uint8_t mode) {
  uint8_t vtFilter  = 0b11000000;
  uint8_t capFilter = 0b00111000;
  writeRegister(AD7745_CONFIGURATION, vtFilter | capFilter | mode);
}

void CDC::writeCAPDAC(bool enabled, uint8_t code) {
  uint8_t enabledFlag = enabled ? 0x80 : 0x00;
  writeRegister(AD7745_CAP_DAC_A, enabledFlag | code);
}

// MARK: - Utilities

void CDC::check(bool transactionResult) {
  if (!transactionResult) {
    Serial.println("Transaction failed.");
    exit(0);
  }
}

float CDC::decodeCapacitance(uint8_t bytes[3]) {
  int32_t integerValue = 0;
  integerValue |= uint32_t(bytes[0]) << 16;
  integerValue |= uint32_t(bytes[1]) << 8;
  integerValue |= uint32_t(bytes[2]);
  integerValue -= 0x800000;

  float floatValue = float(integerValue);
  floatValue /= float(0x800000);
  floatValue *= 4.096;
  return floatValue;
}

float CDC::decodeTemperature(uint8_t bytes[3]) {
  int32_t integerValue = 0;
  integerValue |= uint32_t(bytes[0]) << 16;
  integerValue |= uint32_t(bytes[1]) << 8;
  integerValue |= uint32_t(bytes[2]);
  integerValue -= 0x800000;

  float floatValue = float(integerValue);
  floatValue /= float(2048);
  return floatValue;
}

float CDC::decodeVoltage(uint8_t bytes[3]) {
  int32_t integerValue = 0;
  integerValue |= uint32_t(bytes[0]) << 16;
  integerValue |= uint32_t(bytes[1]) << 8;
  integerValue |= uint32_t(bytes[2]);
  integerValue -= 0x800000;
  
  float floatValue = float(integerValue);
  floatValue /= float(0x800000);
  floatValue *= 1.17;
  return floatValue;
}

float CDC::capdacOffset(uint8_t code) {
  /*
  float output = -0.045;
  output += -0.143071 * float(code);
  return output;
  */

  // CAPDAC needs to be re-calibrated.
  return 0;
}