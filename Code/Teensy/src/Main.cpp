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

  /*
  // CRC on  = 0b10010110
  // CRC off = 0b10000110
  transferDAC2(0x03, 0x00, 0b10010110, false);
  transferDAC2(0x04, 0x00, 0x00);
  transferDAC2(0x09, 0xFF, 0xFE);
  transferDAC2(0x0A, 0x00, 0x05);

  // Set the DAC output voltage.
  transferDAC2(0x10, 0x86, 0x66);

  // Read the device ID. Assert that it is 0x029C (668).
  transferDAC2(0x81, 0x00, 0x00);
  transferDAC2(0x00, 0x00, 0x00);
  */

  uint8_t bytes[3];
  bytes[0] = 0b11001001;
  bytes[1] = 0b11111111;
  bytes[2] = 0b11111110;
  uint32_t polynomial = 0x107;

  uint32_t input = 0;
  input |= bytes[0] << 24;
  input |= bytes[1] << 16;
  input |= bytes[2] << 8;
  
}

void loop() {
  ADC::responsivenessDiagnosticLoop();
}
