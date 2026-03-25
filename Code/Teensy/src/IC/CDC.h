#pragma once

#include <i2c_device.h>

// Functionality to test:
// - capacitance input with settings from spec sheet
// - internal VDD monitor
// - internal temperature sensor (PCB + 0.5°C)

// Main Board:
// - Teensy pin 18 = SDA
// - Teensy pin 19 = SCL
// - equals i2c1 or "Master" with no numbers config

// CDC:
// - address = 0x48 (right-shifted one bit from datasheet 0x90)
// - most significant bit first (big endian)

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
  static void check(bool transactionResult) {
    if (!transactionResult) {
      Serial.println("Transaction failed.");
      exit(0);
    }
  }

  static float decode(uint8_t bytes[3]) {
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
};