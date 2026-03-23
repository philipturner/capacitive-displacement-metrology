#include "IC/ADC.h"
#include "Time/KilohertzLoop.h"
#include "Time/Oscilloscope.h"

Oscilloscope oscilloscope;

void setup() {
  Serial.begin(0);
  Serial.println(); // allow easy distinction of different program runs
  Serial.println("Serial Monitor has initialized.");

  pinMode(CS_ADC, OUTPUT);
  digitalWrite(CS_ADC, 1);
  SPI.begin();

  oscilloscope.initialize();
  Oscilloscope::startFastLoop(&oscilloscope);
}

void loop() {
  oscilloscope.slowLoop();
}
