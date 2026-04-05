#include <Arduino.h>
#include "Metrology.h"

void Metrology::metrologyProgram() {
  changeVoltage(0, -descriptor.bipolarDriveVoltage);
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
      changeVoltage(-descriptor.bipolarDriveVoltage, descriptor.bipolarDriveVoltage);
      capacitances[0] = cdcSingleSample();
      changeVoltage(descriptor.bipolarDriveVoltage, -descriptor.bipolarDriveVoltage);
      capacitances[1] = cdcSingleSample();

      if (descriptor.logSingleSamples) {
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
      }

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
    if (descriptor.verboseDriftCancellation) {
      Serial.print("dC (up)   = ");
      Serial.print(dC_up * 1e6, 1);
      Serial.println(" aF");

      Serial.print("dC (down) = ");
      Serial.print(dC_down * 1e6, 1);
      Serial.println(" aF");
    }

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
    if (descriptor.verboseDriftCancellation) {
      Serial.print("dx (up)   = ");
      Serial.print(dC_up / dCdx, 6);
      Serial.println(" nm");

      Serial.print("dx (down) = ");
      Serial.print(dC_down / dCdx, 6);
      Serial.println(" nm");
    }

    Serial.print("dx (avg)  = ");
    Serial.print(dC_avg / dCdx, 6);
    Serial.println(" nm");    
  }

  changeVoltage(-descriptor.bipolarDriveVoltage, 0);
}