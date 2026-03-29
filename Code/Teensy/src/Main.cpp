#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Time/KilohertzLoop.h"
#include "Time/Oscilloscope.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

TimeStatistics timeStatistics;
void kilohertzLoop();
#define KILOHERTZ_LOOP_PERIOD 4

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();

  KilohertzLoop::initialize(kilohertzLoop, KILOHERTZ_LOOP_PERIOD);
}

void loop() {
  delay(500);

  Serial.println();
  Serial.println(timeStatistics.above1000000us_jumps);
  Serial.println(timeStatistics.above100000us_jumps);
  Serial.println(timeStatistics.above10000us_jumps);
  Serial.println(timeStatistics.above1000us_jumps);
  Serial.println(timeStatistics.above100us_jumps);
  Serial.println(timeStatistics.abovePeriod_jumps);
  Serial.println(timeStatistics.exactlyPeriod_jumps);
  Serial.println(timeStatistics.underPeriod_jumps);
  Serial.println(timeStatistics.total_jumps);
}

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
  uint32_t previous = KilohertzLoop::previousTimestamp;
  uint32_t latest = KilohertzLoop::latestTimestamp;
  uint32_t jumpDuration = latest - previous;
  timeStatistics.integrate(jumpDuration, KILOHERTZ_LOOP_PERIOD);

  // Calculate the period and phase, in microseconds.
  float sineFrequency = 7000;
  uint32_t sinePeriod = uint32_t(float(1e6) / sineFrequency);
  uint32_t phase = latest % sinePeriod;

  float phaseNormalized = float(phase) / float(sinePeriod);
  float waveValue;
  switch ((latest / 1000000) % 4) {
    case 0:
    case 1: {
      waveValue = sineWave(phaseNormalized);
      break;
    }
    case 2: {
      waveValue = squareWave(phaseNormalized);
      break;
    }
    case 3: {
      waveValue = triangleWave(phaseNormalized);
      break;
    }
  }

  // Calculate the voltage.
  float gainFactor = -35.73;
  float offset = -4.58;

  // ax + b = y
  // ax = y - b
  // x = (y - b) / a
  float targetValue = 421 * waveValue;
  float dacValue = (targetValue - offset) / gainFactor;

  DAC1::writeVoltage(1, dacValue);
}