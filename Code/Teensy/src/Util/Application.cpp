#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Application.h"
#include "Bitset.h"

void Application::setupSerial() {
  Serial.begin(0);
  Serial.println(); // allow easy distinction of different program runs
  Serial.println("Serial Monitor has initialized.");
}

void checkDeviceID(uint32_t deviceID, uint32_t expected) {
  if (deviceID != expected) {
    Serial.println("Unexpected device ID.");
    exit(0);
  }
}

void Application::setupSPI() {
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
  ADC::writeRegister(ADS8699_RANGE_SEL_REG, 0b0000);
  uint32_t ADC_ID = ADC::readRegister(ADS8699_DEVICE_ID_REG) >> 16;
  checkDeviceID(ADC_ID, 0b1101);

  // Set up DAC1.
  DAC1::writeRegister(DAC81404_SPICONFIG, 0b10010110, CRC::Flags::NONE);
  DAC1::writeRegister(DAC81404_GENCONFIG, 0x0000, CRC::Flags::MOSI);
  DAC1::writeRegister(DAC81404_DACPWDWN, 0xFFF0);
  DAC1::writeRegister(DAC81404_DACRANGE, 0xEEEE);
  uint16_t DAC1_ID = DAC1::readRegister(DAC81404_DEVICEID) >> 2;
  checkDeviceID(DAC1_ID, 0x029C);

  // Set up DAC2.
  DAC2::writeRegister(DAC81404_SPICONFIG, 0b10010110, CRC::Flags::NONE);
  DAC2::writeRegister(DAC81404_GENCONFIG, 0x0000, CRC::Flags::MOSI);
  DAC2::writeRegister(DAC81404_DACPWDWN, 0xFFFE);
  DAC2::writeRegister(DAC81404_DACRANGE, 0x000E);
  uint16_t DAC2_ID = DAC2::readRegister(DAC81404_DEVICEID) >> 2;
  checkDeviceID(DAC2_ID, 0x029C);

  // Prove responsiveness.
  Serial.print("ADC_ID: ");
  Bitset::printBinary(ADC_ID, 4);
  Serial.println();

  Serial.print("DAC1_ID: ");
  Bitset::printHex(DAC1_ID, 4);
  Serial.println();

  Serial.print("DAC2_ID: ");
  Bitset::printHex(DAC2_ID, 4);
  Serial.println();

  DAC1::writeVoltage(0, -11.0);
  DAC1::writeVoltage(1, -11.1);
  DAC1::writeVoltage(2, 11.2);
  DAC1::writeVoltage(3, 11.3);
  DAC2::writeVoltage(0, -11.5);
}

void Application::setupI2C() {
  CDC::master.begin(400000);

  CDC::writeCapacitanceSetup(true);
  CDC::writeVoltageSetup(false, 0b00);
  CDC::writeRegister(AD7745_EXC_SETUP, 0b00001011);
  CDC::writeConfiguration(0b000);
}