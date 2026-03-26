#include "CDC.h"

void CDC::writeRegister(uint8_t registerAddress, uint8_t value) {
  check(sensor.write(registerAddress, value, true));
}

uint8_t CDC::readRegister(uint8_t registerAddress) {
  uint8_t value = 0;
  check(sensor.read(registerAddress, &value, true));
  return value;
}

// readCapacitance
// readTemperature <- do not correct for theoretical value of self-heating
// readSupplyVoltage <- scale by 5.97

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

