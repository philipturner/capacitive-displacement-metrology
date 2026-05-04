#include "IC/ADC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"

constexpr uint32_t loopPeriod = 6;
constexpr uint32_t programTimeMicroseconds = 3000;
constexpr uint32_t historyLength = programTimeMicroseconds / loopPeriod / 2;
float dataStream1[historyLength];
float dataStream2[historyLength];

void kilohertzLoop();

void setup() {
  Application::setupSerial();
  Application::setupSPI();

  for (uint32_t i = 0; i < historyLength; ++i) {
    dataStream1[i] = 0;
    dataStream2[i] = 0;
  }

  KilohertzLoop::initialize(kilohertzLoop, loopPeriod);
  delay((programTimeMicroseconds + 999) / 1000);
  KilohertzLoop::timer.end();
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

float sineWave(float phaseNormalized) {
  return sin(phaseNormalized * 2 * M_PI);
}

float squareWave(float phaseNormalized) {
  if (phaseNormalized < 0.5) {
    return 1.0;
  } else {
    return -1.0;
  }
}

float triangleWave(float phaseNormalized) {
  float progress;
  if (phaseNormalized < 0.5) {
    progress = 2 * phaseNormalized;
  } else {
    progress = 2 * (1 - phaseNormalized);
  }

  return 2 * progress - 1;
}

void kilohertzLoop() {
  uint32_t elapsedTime = KilohertzLoop::latestTimestamp - KilohertzLoop::startTimestamp;
  uint32_t sinePeriod = 1000; // in microseconds
  uint32_t phase = elapsedTime % sinePeriod;

  float phaseNormalized = float(phase) / float(sinePeriod);
  float waveValueNormalized = triangleWave(phaseNormalized);
  float biasVoltage = 10 * waveValueNormalized;
  DAC2::writeVoltage(0, biasVoltage);

  if (KilohertzLoop::iterationID % 2 == 0) {
    auto conversion = ADC::readVoltage();
    float tiaVoltage = conversion.voltage;

    uint32_t historyIndex = KilohertzLoop::iterationID / 2;
    if (historyIndex < historyLength) {
      dataStream1[historyIndex] = biasVoltage;
      dataStream2[historyIndex] = tiaVoltage;
    }
  }
}