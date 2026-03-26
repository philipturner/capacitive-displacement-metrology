#include "CDC.h"

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

float CDC::decodeSupplyVoltage(uint8_t bytes[3]) {
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