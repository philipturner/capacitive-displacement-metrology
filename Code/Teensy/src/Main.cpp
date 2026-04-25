#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Metrology/Metrology.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

float toneFrequency = 300;
float toneBipolarAmplitude = 50;
uint8_t channelID = 0;
bool toneDiagnostics = true;
void piezoTone(float frequency, uint32_t duration);

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();
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

    if (incomingByte == 'b') {
      channelID = 1;
      piezoTone(1000, 3 * 1000);
    } else if (incomingByte == 'c') {
      channelID = 2;
      piezoTone(1000, 3 * 1000);
    } else if (incomingByte == 'd') {
      channelID = 3;
      piezoTone(1000, 3 * 1000);
    }
  }
}

float squareWave(float phaseNormalized) {
  if (phaseNormalized < 0.5) {
    return 1.0;
  } else {
    return -1.0;
  }
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
  float waveValue = squareWave(phaseNormalized);
  waveValue *= toneBipolarAmplitude;

  PA95::writeVoltage(channelID, waveValue);
}

// frequency: frequency of the tone, in hertz
// duration: time to play the note, in milliseconds
void piezoTone(float frequency, uint32_t duration) {
  if (frequency <= 0) {
    Serial.println("Invalid arguments.");
    exit(0);
  }

  if (toneDiagnostics) {
    float time = float(millis()) / 1000;
    Serial.print("tone ");
    Serial.print(uint32_t(frequency));
    Serial.print(" Hz started at ");
    Serial.print(time, 2);
    Serial.print(" seconds");
    Serial.println();
  }

  toneFrequency = frequency;
  KilohertzLoop::initialize(kilohertzLoop, 4);

  delay(duration);

  KilohertzLoop::timer.end();
  toneFrequency = -1;

  // Debug the strange behavior where the Teensy stops responding.
  if (toneDiagnostics) {
    Serial.println("tone stopped");
  }
}