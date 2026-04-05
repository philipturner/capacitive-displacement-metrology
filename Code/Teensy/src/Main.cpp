#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

// MARK: - Utilities







void metrologyProcedure() {
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

      #if LOG_SINGLE_SAMPLES
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
    #if VERBOSE_DRIFT_CANCELLATION
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
    #if VERBOSE_DRIFT_CANCELLATION
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
}

// MARK: - Setup and Loop

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();
  CDC::writeCAPDAC(true, CDC_CAPDAC_CODE);

  if (mode == Mode::basicMeasurement) {
    CDC::writeConfiguration(AD7745_MD_CONTINUOUS_CONV);
  }

  if (mode == Mode::metrology) {
    metrologyProcedure();
  }
}

void loop() {
  if (mode == Mode::basicMeasurement) {
    basicCapacitanceMeasurementLoop();
  }

  if (mode == Mode::waveformTesting) {
    waveformTestingLoop();
  }
}
