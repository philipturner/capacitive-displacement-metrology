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

// Global variables used by the code
uint32_t toneChannelID = UINT32_MAX;

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();
}

// MARK: - Process Input

void endTone();
void playTone();

// Workaround for problem where the Teensy program won't upload.
void processInput(char incomingByte) {
  if (incomingByte == 'e') {
    endTone();
    return;
  }

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

  playTone();
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
  float waveValueNormalized = triangleWave(phaseNormalized);

  if (toneChannelID >= 1 && toneChannelID <= 3) {
    float voltage = toneVoltagePiezo * waveValueNormalized;
    PA95::writeVoltage(toneChannelID, voltage);
  } else if (toneChannelID == 4) {
    float voltage = toneVoltageBias * waveValueNormalized;
    DAC2::writeVoltage(0, voltage);
  } else {
    Serial.println("Invalid channel ID.");
    exit(0);
  }
}

void endTone() {
  KilohertzLoop::timer.end();

  DAC1::writeVoltage(0, 0.0);
  DAC1::writeVoltage(1, 0.0);
  DAC1::writeVoltage(2, 0.0);
  DAC1::writeVoltage(3, 0.0);

  DAC2::writeVoltage(0, 0.0);
}

void playTone() {
  endTone();
  KilohertzLoop::initialize(kilohertzLoop, 4);
}
