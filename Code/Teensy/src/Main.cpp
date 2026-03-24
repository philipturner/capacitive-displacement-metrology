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

  transferDAC2(0x03, 0x00, 0b10010110, false); // must be false, first time
  transferDAC2(0x04, 0x00, 0x00);
  transferDAC2(0x09, 0xFF, 0xF0);
  transferDAC2(0x0A, 0x55, 0x55);

  // Set the DAC output voltage.
  transferDAC2(0x12, 0x86, 0x66);

  // Read the device ID. It is 0x029C for both chips.
  transferDAC2(0x81, 0x00, 0x00);
  transferDAC2(0x81, 0x00, 0x00);
  transferDAC2(0x81, 0x00, 0x00);
}

void loop() {
  ADC::responsivenessDiagnosticLoop();
}
