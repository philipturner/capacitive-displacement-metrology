#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Metrology/Metrology.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

// Constants to define script behavior
float toneVoltageBias = 1.25;
float toneVoltagePiezo = 420;
float toneFrequency = 1000;
uint32_t toneDuration = 10 * 1000;

// Global variables used by the code
uint32_t toneChannelID = UINT32_MAX;

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();
}

// MARK: - Process Input

void playTone(uint32_t duration);

// Workaround for problem where the Teensy program won't upload.
void processInput(char incomingByte) {
  toneChannelID = UINT32_MAX;
  switch (incomingByte) {
    case '1': {
      toneChannelID = 1;
      break;
    }
    case '2': {
      toneChannelID = 2;
      break;
    }
    case '3': {
      toneChannelID = 3;
      break;
    }
    case '4': {
      toneChannelID = 4;
      break;
    }
    default: {
      return;
    }
  }

  if (incomingByte == '1') {

  } else if (incomingByte == '2') {

  } else if 

  if (incomingByte == 'u') {
    _positiveDriveVoltage = bipolarDriveVoltage;
  } else if (incomingByte == 'd') {
    _positiveDriveVoltage = -bipolarDriveVoltage;
  } else {
    return;
  }

  positiveDriveVoltage =  _positiveDriveVoltage;
  programBody();
  positiveDriveVoltage = 0;
}

void loop() {
  delay(500);

  float time = float(millis()) / 1000;
  Serial.print("time: ");
  Serial.print(time, 2);
  Serial.print(" seconds");
  Serial.println();

  if (Serial.available() > 0) {
    char incomingByte = Serial.read();
    
    processInput(incomingByte);

    // Prevent accidents from multiple key presses.
    while (Serial.available() > 0) {
      char byte = Serial.read();
      Serial.print("ignored input: ");
      Serial.print(byte);
      Serial.println();
    }
  }
}

// MARK: - Play Tone

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
  if (toneFrequency <= 0) {
    Serial.println("Invalid arguments.");
    exit(0);
  }

  uint32_t latest = KilohertzLoop::latestTimestamp;

  // Calculate the period and phase, in microseconds.
  uint32_t sinePeriod = uint32_t(float(1e6) / toneFrequency);
  uint32_t phase = latest % sinePeriod;

  float phaseNormalized = float(phase) / float(sinePeriod);
  float waveValue = triangleWave(phaseNormalized);

  // Calculate the voltage.
  float gainFactor = -35.751;
  float offset = 0.079;
  float dacValue = (targetValue - offset) / gainFactor;
  DAC1::writeVoltage(1, dacValue);
}

void playTone(uint32_t duration) {
  if (true) {
    float time = float(millis()) / 1000;
    Serial.print("tone ");
    Serial.print(uint32_t(toneFrequency));
    Serial.print(" Hz started at ");
    Serial.print(time, 2);
    Serial.print(" seconds");
    Serial.println();
  }

  KilohertzLoop::initialize(kilohertzLoop, 4);

  delay(duration);

  KilohertzLoop::timer.end();

  // Debug the strange behavior where the Teensy stops responding.
  if (true) {
    Serial.println("tone stopped");
  }
}