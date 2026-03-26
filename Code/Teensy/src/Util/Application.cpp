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

  // Set up DAC1.
  DAC1::writeRegister(DAC81404_SPICONFIG, 0b10010110, CRC::Flags::NONE);
  DAC1::writeRegister(DAC81404_GENCONFIG, 0x0000, CRC::Flags::MOSI);
  DAC1::writeRegister(DAC81404_DACPWDWN, 0xFFF0);
  DAC1::writeRegister(DAC81404_DACRANGE, 0x5555);
  uint16_t deviceID1 = DAC1::readRegister(DAC81404_DEVICEID) >> 2;

  // Set up DAC2.
  uint16_t deviceID2 = DAC2::readRegister(DAC81404_DEVICEID) >> 2;

  // Prove responsiveness during current tests.
  Serial.print("deviceID1: ");
  Bitset::printHex(deviceID1, 4);
  Serial.println();

  Serial.print("deviceID2: ");
  Bitset::printHex(deviceID2, 4);
  Serial.println();

  // TODO: Set the voltage of each channel.
}