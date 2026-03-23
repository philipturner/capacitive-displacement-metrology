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

  // Set the DAC output voltage to -1 V
  transferDAC2(0x03, 0x00, 0x84);
  transferDAC2(0x04, 0x00, 0x00);
  transferDAC2(0x09, 0xFF, 0xFE);
  transferDAC2(0x0A, 0x00, 0x05);
  transferDAC2(0x10, 0x56, 0x66);

  // Read the device ID.
  transferDAC2(0x00, 0x00, 0x00);
  transferDAC2(0x81, 0x00, 0x00);
  transferDAC2(0x00, 0x00, 0x00);

  // Device ID = 0x029C
  // SPI_MODE0, FSDO = 0 | 133 56 (0x8538)
  // SPI_MODE0, FSD0 = 1 | 10 112 (0x0A70)
  //
  // Expected: 0x029C | 2 156
  //
  // 0x8538 = 1000010100111000 = 34104
  // 0x0A70 = 0000101001110000 = 2672
  // 0x029C = 0000001010011100 = 668
  //
  // SPI_MODE0, FSDO = 0 | 34104 8526
  // SPI_MODE0, FSDO = 1 | 2672 668
  // SPI_MODE1, FSDO = 0 | 2672 668
  // SPI_MODE1, FSDO = 1 | 2672 668
  // SPI_MODE2, FSDO = 0 | 2672 668 <--
  // SPI_MODE2, FSDO = 1 | 2672 668
  // SPI_MODE3, FSDO = 0 | 0 0
  // SPI_MODE3, FSDO = 1 | 0 0

}

void loop() {
  
}
