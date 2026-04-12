#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Metrology/Metrology.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

float toneFrequency = -1;
float toneBipolarAmplitude = 200;
float toneSlewRate = 5e6;
bool toneDiagnostics = true;
void piezoTone(float frequency, uint32_t duration);

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();
}

void programBody() {
  DAC1::writeVoltage(1, 0);
  piezoTone(300, 20 * 1000);

  // for (uint32_t i = 0; i < 5; ++i) {
  //   piezoTone(1000, 900);
  //   delay(100);
  //   piezoTone(250, 900);
  //   delay(100);
  // }

  DAC1::writeVoltage(1, 0);
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

    if (incomingByte == 'm') {
      programBody();
    }
  }
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

// Piecewise function where 1/3 of the trajectory is a parabola, 2/3 is a line,
// and the regions cross with no discontinuity in velocity.
float piecewiseFunction(float x) {
  float x3 = 3 * x;
  float output;
  if (x3 < 1) {
    output = x3 * x3;
  } else {
    output = 1 + 2 * (x3 - 1);
  }
  return output / 5;
}

// Phase needs to be in microseconds to accurately model the slew rate.
float sawtoothWave(uint32_t phase, uint32_t period) {
  uint32_t halfPeriod = period / 2;

  float waveValue;
  if (phase < halfPeriod) {
    float x = float(phase) / float(halfPeriod);
    waveValue = piecewiseFunction(x);
  } else {
    // Waveform starts distorting at around 16 V/μs.
    float simpleSlewDuration = 2 * toneBipolarAmplitude / toneSlewRate;
    float shortenedSlewDuration = 0.8 * simpleSlewDuration;

    float timeSeconds = float(phase - halfPeriod) / 1e6;
    float x = timeSeconds / shortenedSlewDuration;
    x *= float(2) / float(3);
    if (x >= 1) {
      waveValue = 0;
    } else {
      waveValue = piecewiseFunction(1 - x);
    }
  }
  waveValue = 2 * waveValue - 1;
  return waveValue;
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

  // float phaseNormalized = float(phase) / float(sinePeriod);
  // float waveValue = triangleWave(phaseNormalized);
  float waveValue = sawtoothWave(phase, sinePeriod);
  float targetValue = toneBipolarAmplitude * waveValue;

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
}