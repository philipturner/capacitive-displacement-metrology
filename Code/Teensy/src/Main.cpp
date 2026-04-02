#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

// MARK: - Utilities

constexpr float BIPOLAR_DRIVE_VOLTAGE = 0.75;
constexpr uint8_t CDC_CAPDAC_CODE = 35;

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

// MARK: - Setup and Loop

#define MODE_BASIC_MEASUREMENT 0

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();
  CDC::writeCAPDAC(true, CDC_CAPDAC_CODE);

  #if MODE_BASIC_MEASUREMENT
  CDC::writeConfiguration(AD7745_MD_CONTINUOUS_CONV);

  #else
  changeVoltage(0, -BIPOLAR_DRIVE_VOLTAGE);
  float lastCapacitance = cdcSingleSample();

  for (uint32_t trialID = 0; trialID < 3; ++trialID) {
    // Separate the trials from each other.
    Serial.println();

    constexpr uint32_t sampleCount = 30;
    float dC_up_samples[sampleCount];
    float dC_down_samples[sampleCount];
    float dC_avg_samples[sampleCount];
    float absoluteCapacitance = 0;
    
    for (uint32_t sampleID = 0; sampleID < sampleCount; ++sampleID) {
      float capacitances[2];
      changeVoltage(-BIPOLAR_DRIVE_VOLTAGE, BIPOLAR_DRIVE_VOLTAGE);
      capacitances[0] = cdcSingleSample();
      changeVoltage(BIPOLAR_DRIVE_VOLTAGE, -BIPOLAR_DRIVE_VOLTAGE);
      capacitances[1] = cdcSingleSample();

      #if 0
      // Display the sample number.
      Serial.print("sample ");
      if (sampleID < 100) {
        Serial.print(" ");
      }
      if (sampleID < 10) {
        Serial.print(" ");
      }
      Serial.print(sampleID);
      Serial.print(" | ");

      // Display the absolute capacitance.
      Serial.print("C = ");
      Serial.print(lastCapacitance, 6);
      Serial.print(" -> ");
      Serial.print(capacitances[0], 6);
      Serial.print(" -> ");
      Serial.print(capacitances[1], 6);
      Serial.println();
      #endif

      // Store the difference in capacitance.
      float up = capacitances[0] - lastCapacitance;
      float down = capacitances[0] - capacitances[1];
      dC_up_samples[sampleID] = up;
      dC_down_samples[sampleID] = down;
      dC_avg_samples[sampleID] = (up + down) / 2;

      absoluteCapacitance += capacitances[0];
      absoluteCapacitance += capacitances[1];

      lastCapacitance = capacitances[1];
    }

    // Calculate the combined dC.
    float dC_up = 0;
    float dC_down = 0;
    float dC_avg = 0;
    for (uint32_t sampleID = 0; sampleID < sampleCount; ++sampleID) {
      dC_up += dC_up_samples[sampleID];
      dC_down += dC_down_samples[sampleID];
      dC_avg += dC_avg_samples[sampleID];
    }
    dC_up /= float(sampleCount);
    dC_down /= float(sampleCount);
    dC_avg /= float(sampleCount);

    absoluteCapacitance /= 2 * float(sampleCount);

    // Present the combined dC.
    #if 0
    Serial.print("dC (up)   = ");
    Serial.print(dC_up * 1e6, 1);
    Serial.println(" aF");

    Serial.print("dC (down) = ");
    Serial.print(dC_down * 1e6, 1);
    Serial.println(" aF");
    #endif

    Serial.print("dC (avg)  = ");
    Serial.print(dC_avg * 1e6, 1);
    Serial.println(" aF");

    Serial.print("C = ");
    Serial.print(absoluteCapacitance, 6);
    Serial.println(" pF");

    

    // Convert to distance.
    float separation = 8.854e-12 * 10e-3 * 10e-3;
    separation /= absoluteCapacitance * 1e-12; // pF -> F
    Serial.print("[parallel plate model] ");
    Serial.print("x = ");
    Serial.print(separation * 1e6, 1);
    Serial.println(" μm");

    float dCdx = -8.854e-12 * 10e-3 * 10e-3;
    dCdx /= separation * separation;
    dCdx *= 1e12; // F -> pF
    dCdx *= 1e-9; // m^-1 -> nm^-1
    Serial.print("[parallel plate model] ");
    Serial.print("dC/dx = ");
    Serial.print(dCdx, 6);
    Serial.println(" pF/nm");

    // Present the estimated dx.
    #if 0
    Serial.print("dx (up)   = ");
    Serial.print(dC_up / dCdx, 6);
    Serial.println(" nm");

    Serial.print("dx (down) = ");
    Serial.print(dC_down / dCdx, 6);
    Serial.println(" nm");
    #endif

    Serial.print("dx (avg)  = ");
    Serial.print(dC_avg / dCdx, 6);
    Serial.println(" nm");
    
  }

  changeVoltage(-BIPOLAR_DRIVE_VOLTAGE, 0);
  #endif
}

void loop() {
  #if MODE_BASIC_MEASUREMENT
  basicCapacitanceMeasurementLoop();
  #endif
}
