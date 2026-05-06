#include "IC/ADC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"

// MARK: - Constants

constexpr uint32_t loopPeriod = 6;
constexpr uint32_t bufferTimeMicroseconds = 50000;
constexpr uint32_t bufferLength = bufferTimeMicroseconds / loopPeriod / 2;
float dataStream1[bufferLength];
float dataStream2[bufferLength];

// MARK: - Mode

enum class Mode {
  riseTime = 0,
  noise = 1,
};
Mode mode = Mode::riseTime;

uint32_t getProgramTimeMicroseconds(Mode mode) {
  if (mode == Mode::riseTime) {
    return 3000;
  } else {
    return 50000;
  }
}

uint32_t getHistoryLength(Mode mode) {
  uint32_t programTimeMicroseconds = getProgramTimeMicroseconds(mode);
  return programTimeMicroseconds / loopPeriod / 2;
}

// MARK: - Program

void setup() {
  Application::setupSerial();
  Application::setupSPI();
}

void kilohertzLoop();

void runProgram() {
  for (uint32_t i = 0; i < bufferLength; ++i) {
    dataStream1[i] = 0;
    dataStream2[i] = 0;
  }

  KilohertzLoop::initialize(kilohertzLoop, loopPeriod);
  delay((getProgramTimeMicroseconds(mode) + 999) / 1000);
  KilohertzLoop::timer.end();

  Serial.print(">");
  Serial.print("id:start,");
  Serial.print("time (μs),stimulus (a.u.),current (pA),");
  Serial.print("<");
  Serial.println();

  for (uint32_t i = 0; i < getHistoryLength(mode); ++i) {
    uint32_t timeMicros = i * (loopPeriod * 2);

    // Identifier to debug serial acquisition.
    Serial.print(">");
    Serial.print("id:");
    Serial.print(i);
    Serial.print(",");
    
    Serial.print(float(timeMicros), 1);
    Serial.print(",");

    if (mode == Mode::riseTime) {
      Serial.print(dataStream1[i] * 30, 4);
    } else {
      Serial.print(dataStream1[i], 4);
    }
    Serial.print(",");
    
    Serial.print(dataStream2[i] * 1000, 4);
    Serial.print(",");

    Serial.print("<");
    Serial.println();
  }

  Serial.print(">");
  Serial.print("id:end,");
  Serial.print("<");
  Serial.println();
}

// MARK: - Process Input

void processInput() {
  char incomingByte = Serial.read();

  if (incomingByte == 'e') {
    runProgram();
  } else if (incomingByte == 'r') {
    mode = Mode::riseTime;
  } else if (incomingByte == 'n') {
    mode = Mode::noise;
  }
}

void loop() {
  delay(50);

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

  float biasVoltage;
  if (mode == Mode::riseTime) {
    float phaseNormalized = float(phase) / float(sinePeriod);
    float waveValueNormalized = triangleWave(phaseNormalized);
    biasVoltage = 10 * waveValueNormalized;
    DAC2::writeVoltage(0, biasVoltage);
  } else {
    biasVoltage = 0;
    
    // Don't write to the DAC when characterizing the preamp's noise. It shifts
    // the average current by 0.2 pA in either direction.
    delayMicroseconds(2);
  }
  
  if (KilohertzLoop::iterationID % 2 == 0) {
    auto conversion = ADC::readVoltage();
    float tiaVoltage = conversion.voltage;

    uint32_t historyIndex = KilohertzLoop::iterationID / 2;
    if (historyIndex < getHistoryLength(mode)) {
      dataStream1[historyIndex] = biasVoltage;
      dataStream2[historyIndex] = tiaVoltage;
    }
  }
}