#include "IC/ADC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"

void kilohertzLoop();

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  KilohertzLoop::initialize(kilohertzLoop, 20);
}

// MARK: - Process Input

void processInput() {
  char incomingByte = Serial.read();
}

void loop() {
  delay(500);

  float time = float(millis()) / 1000;
  Serial.print("time: ");
  Serial.print(time, 2);
  Serial.print(" seconds");
  Serial.println();

  if (Serial.available() > 0) {
    processInput();

    // Prevent accidents from multiple key presses.
    while (Serial.available() > 0) {
      char byte = Serial.read();
      Serial.print("ignored input: ");
      Serial.print(byte);
      Serial.println();
    }
  }
}

// MARK: - Kilohertz Loop

void kilohertzLoop() {
  uint32_t previous = KilohertzLoop::previousTimestamp;
  uint32_t latest = KilohertzLoop::latestTimestamp;
  uint32_t jumpDuration = latest - previous;
}