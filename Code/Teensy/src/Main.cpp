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
uint32_t toneChannelID = 4;

// Global variables used by the code
WaveType waveType = WaveType::sineWave;
float toneFrequency = 1000;

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();
}

// MARK: - Process Input

void endTone();
void playTone();

bool isDigit(char byte) {
  return (byte >= '0') && (byte <= '9');
}

uint32_t getDigit(char byte) {
  return byte - '0';
}

// Workaround for problem where the Teensy program won't upload.
void processInput() {
  char incomingByte = Serial.read();

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

  if (incomingByte == 'p') {
    playTone();
    return;
  }
  if (incomingByte == 'e') {
    endTone();
    return;
  }

  if (!isDigit(incomingByte)) {
    return;
  }

  uint32_t frequency = getDigit(incomingByte);
  while (Serial.available() > 0) {
    char incomingByte = Serial.read();
    if (!isDigit(incomingByte)) {
      Serial.println("Invalid number entered.");
      exit(0);
    }

    uint32_t digit = getDigit(incomingByte);
    frequency = frequency * 10 + digit;
  }
  Serial.print("Changed frequency to: ");
  Serial.print(frequency, 1);
  Serial.println();

  toneFrequency = float(frequency);
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
