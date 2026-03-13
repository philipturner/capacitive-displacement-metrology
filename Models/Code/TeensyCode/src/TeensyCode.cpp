#include "IC/ADC.h"
#include "Time/KeyboardInput.h"
#include "Time/KilohertzLoop.h"

IntervalTimer timer;

void setup() {
  Serial.begin(0);
  Serial.println(); // allow easy distinction of different program runs
  Serial.println("Serial Monitor has initialized.");

  pinMode(CS_ADC, OUTPUT);
  digitalWrite(CS_ADC, 1);
  SPI.begin();

  startTimestamp = micros();
  latestTimestamp = startTimestamp;
  oscilloscopeTimestamp = startTimestamp;
  timer.begin(kilohertzLoop, 20);
}

void loop() {
  oscilloscopeDiagnosticLoop();
}
