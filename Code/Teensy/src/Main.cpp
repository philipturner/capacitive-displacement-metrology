#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Metrology/Metrology.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"
#include "Util/Rickroll.h"

float sineFrequency = -1;
void piezoTone(float frequency, uint32_t duration);

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();

  for (uint32_t i = 0; i < 50; ++i) {
    piezoTone(1000, 900);
    delay(100);
    piezoTone(250, 900);
    delay(100);
  }
}

void loop() {

}

void kilohertzLoop() {
  if (sineFrequency <= 0) {
    Serial.println("Invalid arguments.");
    exit(0);
  }

  uint32_t latest = KilohertzLoop::latestTimestamp;

  // Calculate the period and phase, in microseconds.
  uint32_t sinePeriod = uint32_t(float(1e6) / sineFrequency);
  uint32_t phase = latest % sinePeriod;

  float phaseNormalized = float(phase) / float(sinePeriod);
  float waveValue = sin(phaseNormalized * 2 * M_PI);
  float targetValue = 420 * waveValue;

  // Calculate the voltage.
  float gainFactor = -35.751;
  float offset = 0.079;
  float dacValue = (targetValue - offset) / gainFactor;
  DAC1::writeVoltage(1, dacValue);
}

// frequency: frequency of the tone, in hertz
// duration: time to play the note, in milliseconds
void piezoTone(float frequency, uint32_t duration) {
  if (frequency <= 0) {
    Serial.println("Invalid arguments.");
    exit(0);
  }

  float time = float(millis()) / 1000;
  Serial.print("tone ");
  Serial.print(uint32_t(frequency));
  Serial.print(" Hz started at ");
  Serial.print(time, 2);
  Serial.print(" seconds");
  Serial.println();

  sineFrequency = frequency;
  KilohertzLoop::initialize(kilohertzLoop, 4);

  delay(duration);

  KilohertzLoop::timer.end();
  sineFrequency = -1;
}