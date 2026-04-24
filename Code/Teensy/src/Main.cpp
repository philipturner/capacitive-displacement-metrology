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
float toneBipolarAmplitude = 360;
uint8_t channelID = 3;
void kilohertzLoop();

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();

  KilohertzLoop::initialize(kilohertzLoop, 4);
}

void loop() {

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