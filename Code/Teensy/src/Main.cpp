#include "IC/ADC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"

constexpr uint32_t loopPeriod = 6;

TimeStatistics timeStatistics;

void kilohertzLoop();

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  KilohertzLoop::initialize(kilohertzLoop, loopPeriod);
}

// MARK: - Process Input

void processInput() {
  char incomingByte = Serial.read();
}

void loop() {
  delay(500);

  float time = float(millis()) / 1000;
  Serial.println();
  Serial.print("time: ");
  Serial.print(time, 2);
  Serial.print(" seconds");

  Serial.println();
  timeStatistics.display();

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
  timeStatistics.integrate(jumpDuration, loopPeriod);

  DAC2::writeVoltage(0, 0.0);
  ADC::readVoltage();
}