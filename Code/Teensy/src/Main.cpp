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
}

void runProgram() {
  for (uint32_t i = 0; i < historyLength; ++i) {
    dataStream1[i] = 0;
    dataStream2[i] = 0;
  }

  KilohertzLoop::initialize(kilohertzLoop, loopPeriod);
  delay((programTimeMicroseconds + 999) / 1000);
  KilohertzLoop::timer.end();

  Serial.print("id:start");
  Serial.print(">time (s),stimulus (a.u.),current (pA)");

  for (uint32_t i = 0; i < historyLength; ++i) {
    uint32_t timeMicros = i * (loopPeriod * 2);

    // Identifier to debug serial acquisition.
    Serial.print("id:");
    Serial.print(i);
    Serial.println();
    
    // Don't display the large spike at the beginning.
    if (timeMicros < 200) {
      continue;
    }

    float timeSeconds = float(timeMicros) / 1e6;

    // This graphing has too poor of quality and customizability.
    // Try using PySerial and Matplotlib tomorrow, creating a GUI
    // application that steals the serial port and supports inputting
    // characters to the Arduino.
    //
    // Ideally, it accepts characters from a command-line terminal and
    // opens a Matplotlib window that updates in real-time. The graph
    // window should not override the keyboard's focus on the terminal.
    // It should not involve any GUI programming.
    Serial.print(">stimulus (a.u.):");
    Serial.print(timeSeconds, 6);
    Serial.print(":");
    Serial.print(dataStream1[i] * 30, 4);
    Serial.println();

    Serial.print(">current (pA):");
    Serial.print(timeSeconds, 6);
    Serial.print(":");
    Serial.print(dataStream2[i] * 1000, 4);
    Serial.println();
  }
}

// MARK: - Process Input

void processInput() {
  char incomingByte = Serial.read();

  if (incomingByte == 'r') {
    runProgram();
  }
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