#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Application.h"

extern "C" void usb_init();

void Application::setupSerial() {
  // More robust solution:
  //
  // https://community.platformio.org/t/how-to-modify-teensy-core-files/7425/5
  // Change USB speed from 480 to 12 Mbps by uncommenting the line in:
  // https://github.com/PaulStoffregen/cores/blob/master/teensy4/usb.c
  // Needs to be reimplemented after updating the Teensy PlatformIO package.
  //
  // More elegant solution here only works with external program polling Serial.
  // It locks up PlatformIO's serial implementation for some reason. Use the
  // `#if` macro to disable the patch for tests that don't stress IO bandwidth.
  #if 0
  USB1_USBCMD = 0; // turn off USB controller
  USB1_USBCMD = 2; // begin USB controller reset
  delay(250);
  usb_init();
  USB1_PORTSC1 |= USB_PORTSC1_PFSC; // force 12 Mbit/sec
  #endif
  
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
  ADC::writeRegister(ADS8699_RANGE_SEL_REG, ADS8699_RANGE_12V_BIPOLAR);
  uint32_t ADC_ID = ADC::readRegister(ADS8699_DEVICE_ID_REG) >> 16;
  checkDeviceID(ADC_ID, 0b1101);

  // Set up DAC1.
  DAC1::writeRegister(DAC81404_SPICONFIG, 0b10010110, CRC::Flags::NONE);
  DAC1::writeRegister(DAC81404_GENCONFIG, 0x0000, CRC::Flags::MOSI);
  DAC1::writeRegister(DAC81404_DACPWDWN, 0xFFF0);
  DAC1::writeRegister(DAC81404_DACRANGE, 0x1111 * DAC81404_RANGE_12V_BIPOLAR);
  uint16_t DAC1_ID = DAC1::readRegister(DAC81404_DEVICEID) >> 2;
  checkDeviceID(DAC1_ID, 0x029C);

  DAC1::writeVoltage(0, 0.0);
  DAC1::writeVoltage(1, 0.0);
  DAC1::writeVoltage(2, 0.0);
  DAC1::writeVoltage(3, 0.0);

  // Set up DAC2.
  DAC2::writeRegister(DAC81404_SPICONFIG, 0b10010110, CRC::Flags::NONE);
  DAC2::writeRegister(DAC81404_GENCONFIG, 0x0000, CRC::Flags::MOSI);
  DAC2::writeRegister(DAC81404_DACPWDWN, 0xFFFE);
  DAC2::writeRegister(DAC81404_DACRANGE, 0x0001 * DAC81404_RANGE_12V_BIPOLAR);
  uint16_t DAC2_ID = DAC2::readRegister(DAC81404_DEVICEID) >> 2;
  checkDeviceID(DAC2_ID, 0x029C);

  DAC2::writeVoltage(0, 0.0);
}

void Application::setupI2C() {
  CDC::master.begin(400000);

  CDC::writeCapacitanceSetup(true, false);
  CDC::writeVoltageSetup(false, 0b00);

  // Never activate EXCB with the 2nd CDC! This could break the chip.
  CDC::writeRegister(AD7745_EXC_SETUP, 0b00001011);
  CDC::writeConfiguration(AD7745_MD_IDLE);

  // Turn the CAPDAC off by default, for now.
  CDC::writeCAPDAC(false, 0);

  // Clear any previous measurement data.
  CDC::readCapacitance();
}