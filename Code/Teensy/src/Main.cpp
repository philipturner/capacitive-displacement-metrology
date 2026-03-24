#include "IC/ADC.h"
#include "IC/DAC.h"
#include "Time/KilohertzLoop.h"
#include "Time/Oscilloscope.h"

void setup() {
  Serial.begin(0);
  Serial.println(); // allow easy distinction of different program runs
  Serial.println("Serial Monitor has initialized.");

  pinMode(CS_DAC1, OUTPUT);
  pinMode(CS_DAC2, OUTPUT);
  pinMode(CS_ADC, OUTPUT);
  digitalWrite(CS_DAC1, 1);
  digitalWrite(CS_DAC2, 1);
  digitalWrite(CS_ADC, 1);
  SPI.begin();

  ADC::writeRegister(ADS8699_DATAOUT_CTL_REG, 0b1000);

  /*

  // 0x84 | FSDO = 0
  // 0x86 | FSDO = 1
  transferDAC2(0x03, 0x00, 0x86);
  transferDAC2(0x04, 0x00, 0x00);
  transferDAC2(0x09, 0xFF, 0xFE);
  transferDAC2(0x0A, 0x00, 0x05);

  // Set the DAC output voltage.
  transferDAC2(0x10, 0x86, 0x66);

  // Read the device ID. Assert that it is 0x029C (668).
  transferDAC2(0x81, 0x00, 0x00);
  transferDAC2(0x00, 0x00, 0x00);

  */
}

void loop() {
  ADC::responsivenessDiagnosticLoop();
}
