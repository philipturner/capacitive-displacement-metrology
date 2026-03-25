#include "IC/ADC.h"
#include "IC/DAC.h"
#include "Time/KilohertzLoop.h"
#include "Time/Oscilloscope.h"
#include "Util/Bitset.h"

void setup() {
  // Set up USB serial.
  Serial.begin(0);
  Serial.println(); // allow easy distinction of different program runs
  Serial.println("Serial Monitor has initialized.");

  // Set up SPI.
  pinMode(CS_DAC1, OUTPUT);
  pinMode(CS_DAC2, OUTPUT);
  pinMode(CS_ADC, OUTPUT);
  digitalWrite(CS_DAC1, 1);
  digitalWrite(CS_DAC2, 1);
  digitalWrite(CS_ADC, 1);
  SPI.begin();

  // Set up ADC.
  ADC::writeRegister(ADS8699_DATAOUT_CTL_REG, 0x4000 | 0b1000);
  ADC::writeRegister(ADS8699_DEVICE_ID_REG + 2, 0b1101);

  DAC2::transfer(0x03, 0x00, 0b10010110, CRC::Flags::NONE);

  DAC1::transfer(0x03, 0x00, 0b10010110, CRC::Flags::NONE);
  DAC1::transfer(0x04, 0x00, 0x00, CRC::Flags::MOSI);
  DAC1::transfer(0x09, 0xFF, 0xF0, CRC::Flags::MOSI | CRC::Flags::MISO_FLAG);
  DAC1::transfer(0x0A, 0x55, 0x55, CRC::Flags::MOSI | CRC::Flags::MISO_FLAG);

  // Set the DAC output voltage.
  DAC1::transfer(0x12, 0x86, 0x66, CRC::Flags::MOSI | CRC::Flags::MISO_FLAG);

  // Read the device ID. It is 0x029C for both chips.
  DAC1::transfer(0x81, 0x00, 0x00, CRC::Flags::MOSI | CRC::Flags::MISO_FLAG);
  uint16_t deviceID = DAC1::transfer(0x81, 0x00, 0x00, CRC::Flags::MOSI | CRC::Flags::MISO_FLAG | CRC::Flags::MISO_VALIDITY);
  uint16_t deviceIDAgain = DAC1::transfer(0x81, 0x00, 0x00, CRC::Flags::MOSI | CRC::Flags::MISO_FLAG | CRC::Flags::MISO_VALIDITY);

  Serial.print("deviceID: ");
  Serial.print(deviceID);
  Serial.print(" ");
  Serial.println(deviceIDAgain);

  Serial.print("expected: ");
  Serial.print(0x029C);
  Serial.print(" ");
  Serial.println(0x029C);
}

void loop() {
  
}
