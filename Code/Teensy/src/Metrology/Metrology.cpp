#include "IC/CDC.h"
#include "IC/DAC.h"
#include <Arduino.h>
#include "Metrology.h"

Metrology::Metrology() {
  this->capacitanceHistory = NULL;
}

Metrology::~Metrology() {
  if (capacitanceHistory) {
    free(capacitanceHistory);
    capacitanceHistory = NULL;
  }
}

Metrology::Metrology(Descriptor descriptor) {
  this->descriptor = descriptor;
  this->capacitanceHistory = (float*)malloc(descriptor.samplesPerAverage);

  CDC::writeCAPDAC(true, descriptor.cdcCapdacCode);
  CDC::writeCapacitanceSetup(true, true);

  if (descriptor.mode == Mode::basicMeasurement) {
    CDC::writeConfiguration(AD7745_MD_CONTINUOUS_CONV);
  }

  if (descriptor.mode == Mode::metrology) {
    metrologyProgram();
  }
}

void Metrology::loop() {
  if (descriptor.mode == Mode::basicMeasurement) {
    basicCapacitanceMeasurementLoop();
  }

  if (descriptor.mode == Mode::waveformTesting) {
    waveformTestingLoop();
  }
}

float Metrology::smoothstep(float progress) {
  if (progress < 0) {
    return 0;
  } else if (progress > 1) {
    return 1;
  } else {
    float x3 = progress * progress * progress;
    float x4 = x3 * progress;
    float x5 = x3 * progress * progress;
    return 6 * x5 - 15 * x4 + 10 * x3;
  }
}

void Metrology::changeVoltage(float startVoltage, float endVoltage) {
  constexpr uint32_t stallTimeMicroseconds = 4;
  constexpr float duration = 10e-3;

  uint32_t startTime = micros();
  while (true) {
    delayMicroseconds(stallTimeMicroseconds);
    uint32_t latestTime = micros();
    float elapsedTime = float(latestTime - startTime) / float(1e6);

    float timeProgress = elapsedTime / duration;
    float voltageProgress = smoothstep(timeProgress);

    float voltage = 0;
    voltage += voltageProgress * endVoltage;
    voltage += (1 - voltageProgress) * startVoltage;

    // Correct for the PA95 transfer function.
    float gainFactor = -35.751;
    float offset = 0.079;
    float dacValue = (voltage - offset) / gainFactor;
    DAC1::writeVoltage(1, dacValue);

    if (elapsedTime > duration) {
      break;
    }
  }

  // Minimize possible interference from voltage-dependent decay times.
  delay(5);
}

float Metrology::cdcSingleSample() {
  if (!(CDC::readRegister(AD7745_STATUS) & 0b00000100)) {
    Serial.println("A previous measurement was queued.");
    exit(0);
  }

  // Assumes CAPCHOP is enabled, otherwise the delay is more than necessary.
  CDC::writeConfiguration(AD7745_MD_SINGLE_CONV);
  delay(115 * 2);

  if (CDC::readRegister(AD7745_STATUS) & 0b00000100) {
    Serial.println("Measurement is not ready.");
    exit(0);
  }

  float capacitance = CDC::readCapacitance();
  capacitance -= CDC::capdacOffset(descriptor.cdcCapdacCode);
  return capacitance;
}