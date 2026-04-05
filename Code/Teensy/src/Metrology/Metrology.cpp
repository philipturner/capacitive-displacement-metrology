#include "MetrologyUtil.h"

#define CDC_HISTORY_SIZE 27
float capacitanceHistory[CDC_HISTORY_SIZE] = {};
uint32_t infiniteLoopIndex = 0;

// Input: progress, 0 to 1
// Output: interpolation, 0 to 1
float smoothstep(float progress) {
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

void changeVoltage(float startVoltage, float endVoltage) {
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
}

void waveformTestingLoop() {
  delay(10);
  changeVoltage(-BIPOLAR_DRIVE_VOLTAGE, BIPOLAR_DRIVE_VOLTAGE);
  delay(10);
  changeVoltage(BIPOLAR_DRIVE_VOLTAGE, -BIPOLAR_DRIVE_VOLTAGE);
}

// CDC must be in continuous conversion mode.
void basicCapacitanceMeasurementLoop() {
  delay(10);

  uint8_t status = CDC::readRegister(AD7745_STATUS);
  if (status & 0b00000100) {
    return;
  }

  float time = float(millis()) / 1000;
  float capacitance = CDC::readCapacitance();
  capacitance -= CDC::capdacOffset(CDC_CAPDAC_CODE);
  capacitanceHistory[infiniteLoopIndex % CDC_HISTORY_SIZE] = capacitance;
  infiniteLoopIndex += 1;

  // Calculate the trailing average.
  float capacitanceAverage = 0;
  for (uint32_t i = 0; i < CDC_HISTORY_SIZE; ++i) {
    float sample = capacitanceHistory[i];
    capacitanceAverage += sample;
  }
  capacitanceAverage /= float(CDC_HISTORY_SIZE);

  // Display the capacitance.
  Serial.println();

  Serial.print("time: ");
  Serial.print(time, 3);
  Serial.println(" s");

  Serial.print("capacitance:                 ");
  Serial.print(capacitance, 6);
  Serial.println(" pF");

  if (CDC_HISTORY_SIZE < 100) {
    Serial.print(" ");
  }
  Serial.print(CDC_HISTORY_SIZE);
  Serial.print("-sample trailing average: ");
  Serial.print(capacitanceAverage, 6);
  Serial.println(" pF");
}

float cdcSingleSample() {
  if (!(CDC::readRegister(AD7745_STATUS) & 0b00000100)) {
    Serial.println("A previous measurement was queued.");
    exit(0);
  }

  CDC::writeConfiguration(AD7745_MD_SINGLE_CONV);
  delay(115 * 2);

  if (CDC::readRegister(AD7745_STATUS) & 0b00000100) {
    Serial.println("Measurement is not ready.");
    exit(0);
  }

  float capacitance = CDC::readCapacitance();
  capacitance -= CDC::capdacOffset(CDC_CAPDAC_CODE);
  return capacitance;
}