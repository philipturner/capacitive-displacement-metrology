#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Metrology/Metrology.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

enum class WaveType: uint32_t {
  sineWave = 0,
  triangleWave = 1,
  squareWave = 2,
};

// Constants to define script behavior
float toneVoltageBias = 10;
float toneVoltagePiezo = 420;
float toneFrequency = 1000;

// Global variables used by the code
WaveType waveType = WaveType::sineWave;
uint32_t toneChannelID = UINT32_MAX;

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();
}

// MARK: - Process Input

void endTone();
void playTone();
void forceAll(float value);

// Workaround for problem where the Teensy program won't upload.
void processInput(char incomingByte) {
  if (incomingByte == 's') {
    waveType = WaveType::sineWave;
    return;
  }
  if (incomingByte == 't') {
    waveType = WaveType::triangleWave;
    return;
  }
  if (incomingByte == 'q') {
    waveType = WaveType::squareWave;
    return;
  }

  if (incomingByte == 'e') {
    endTone();
    return;
  }

  if (incomingByte == '+') {
    forceAll(12.0);
    return;
  }
  if (incomingByte == '-') {
    forceAll(-12.0);
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
  float waveValueNormalized = 0;
  switch (waveType) {
    case WaveType::sineWave: {
      waveValueNormalized = sineWave(phaseNormalized);
      break;
    }
    case WaveType::triangleWave: {
      waveValueNormalized = triangleWave(phaseNormalized);
      break;
    }
    case WaveType::squareWave: {
      waveValueNormalized = squareWave(phaseNormalized);
      break;
    }
  }

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

void forceAll(float value) {
  endTone();

  DAC1::writeVoltage(0, value);
  DAC1::writeVoltage(1, value);
  DAC1::writeVoltage(2, value);
  DAC1::writeVoltage(3, value);

  DAC2::writeVoltage(0, value);
}