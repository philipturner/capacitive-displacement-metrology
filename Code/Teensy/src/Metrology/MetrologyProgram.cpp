#include <Arduino.h>
#include "Metrology.h"

struct Trial {
  static constexpr uint32_t sampleCount = 30;
  float up[sampleCount];
  float down[sampleCount];
  float avg[sampleCount];

  struct Average {
    float up;
    float down;
    float avg;
  };

  Average getAverage() {
    float dC_up = 0;
    float dC_down = 0;
    float dC_avg = 0;
    for (uint32_t sampleID = 0; sampleID < Trial::sampleCount; ++sampleID) {
      dC_up += up[sampleID];
      dC_down += down[sampleID];
      dC_avg += avg[sampleID];
    }
    dC_up /= float(sampleCount);
    dC_down /= float(sampleCount);
    dC_avg /= float(sampleCount);

    return { dC_up, dC_down, dC_avg };
  }
};

void displayEstimatedDuration(Metrology::ProgramDescriptor programDesc) {
  float sampleTime = 0.010 + 0.005 + 0.230;
  if (programDesc.creepTime > 0) {
    sampleTime += 0.010 + 0.005 + programDesc.creepTime + 0.230;
  }

  float sampleCount = float(Trial::sampleCount);
  sampleCount *= float(Metrology::ProgramResult::trialCount);
  sampleCount += 0.5;

  float timeSeconds = sampleCount * sampleTime;
  float timeMinutes = timeSeconds / 60;
  Serial.print("estimated program duration: ");
  Serial.print(timeMinutes, 1);
  Serial.println(" min");
}

void displayCapacitanceChange(float dC, float dC_creep, bool enableCreep) {
  Serial.print(dC * 1e6, 1);
  Serial.print(" aF");

  if (enableCreep) {
    Serial.print(" -> ");
    Serial.print(dC_creep * 1e6, 1);
    Serial.print(" aF");
  }

  Serial.println();
}

void displayDistanceChange(float dx, float dx_creep, bool enableCreep) {
  Serial.print(dx, 1);
  Serial.print(" nm");

  if (enableCreep) {
    Serial.print(" -> ");
    Serial.print(dx_creep, 1);
    Serial.print(" nm");
  }

  Serial.println();
}

void creepDelay(Metrology::ProgramDescriptor programDesc) {
  uint32_t creepTimeInMs = uint32_t(round(programDesc.creepTime * 1e3));
  delay(creepTimeInMs);
}

Metrology::ProgramResult Metrology::metrologyProgram(
  Metrology::ProgramDescriptor programDesc
) {
  if (metrologyDesc.mode != Mode::metrology) {
    Serial.print("Can only call this function in metrology mode.");
    exit(0);
  }

  displayEstimatedDuration(programDesc);

  changeVoltage(0, -programDesc.bipolarVoltage);
  float lastCapacitance1 = cdcSingleSample();

  // Correct for an initial time offset that messes up the values of
  // up/down.
  float lastCapacitance2;
  if (programDesc.creepTime > 0) {
    creepDelay(programDesc);
    lastCapacitance2 = cdcSingleSample();
  } else {
    lastCapacitance2 = lastCapacitance1;
  }
  
  ProgramResult output;
  for (uint32_t trialID = 0; trialID < ProgramResult::trialCount; ++trialID) {
    // Separate the trials from each other.
    Serial.println();
    float absoluteCapacitance = 0;
    Trial trial;
    Trial creepTrial;
    
    for (uint32_t sampleID = 0; sampleID < Trial::sampleCount; ++sampleID) {      
      float capacitances[4];
      
      changeVoltage(-programDesc.bipolarVoltage, programDesc.bipolarVoltage);
      capacitances[0] = cdcSingleSample();

      if (programDesc.creepTime > 0) {
        creepDelay(programDesc);
        capacitances[1] = cdcSingleSample();
      } else {
        capacitances[1] = capacitances[0];
      }

      changeVoltage(programDesc.bipolarVoltage, -programDesc.bipolarVoltage);
      capacitances[2] = cdcSingleSample();

      if (programDesc.creepTime > 0) {
        creepDelay(programDesc);
        capacitances[3] = cdcSingleSample();
      } else {
        capacitances[3] = capacitances[2];
      }

      if (programDesc.logSingleSamples) {
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
        Serial.print(lastCapacitance2, 6);

        Serial.print(" -> ");
        Serial.print(capacitances[0], 6);
        if (programDesc.creepTime > 0) {
          Serial.print(" -> ");
          Serial.print(capacitances[1], 6);
        }
        Serial.print(" -> ");
        Serial.print(capacitances[2], 6);
        if (programDesc.creepTime > 0) {
          Serial.print(" -> ");
          Serial.print(capacitances[3], 6);
        }
        Serial.println();
      }

      // Store the difference in capacitance.
      float up = capacitances[0] - lastCapacitance1;
      float down = capacitances[0] - capacitances[2];
      trial.up[sampleID] = up;
      trial.down[sampleID] = down;
      trial.avg[sampleID] = (up + down) / 2;

      // This difference should be slightly larger, due to creep.
      float up_creep = capacitances[1] - lastCapacitance2;
      float down_creep = capacitances[1] - capacitances[3];
      creepTrial.up[sampleID] = up_creep;
      creepTrial.down[sampleID] = down_creep;
      creepTrial.avg[sampleID] = (up_creep + down_creep) / 2;

      absoluteCapacitance += capacitances[1];
      absoluteCapacitance += capacitances[3];

      lastCapacitance1 = capacitances[2];
      lastCapacitance2 = capacitances[3];      
    }

    // Calculate the combined dC.
    Trial::Average dC = trial.getAverage();
    Trial::Average dC_creep = creepTrial.getAverage();
    absoluteCapacitance /= 2 * float(Trial::sampleCount);

    // Present the combined dC.
    if (programDesc.verboseDriftCancellation) {
      Serial.print("dC (up)   = ");
      displayCapacitanceChange(
        dC.up, dC_creep.up, programDesc.creepTime > 0);

      Serial.print("dC (down) = ");
      displayCapacitanceChange(
        dC.down, dC_creep.down, programDesc.creepTime > 0);
    }

    Serial.print("dC (avg)  = ");
    displayCapacitanceChange(
        dC.avg, dC_creep.avg, programDesc.creepTime > 0);

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
    if (programDesc.verboseDriftCancellation) {
      Serial.print("dx (up)   = ");
      displayDistanceChange(
        dC.up / dCdx, 
        dC_creep.up / dCdx,
        programDesc.creepTime > 0);
    
      Serial.print("dx (down) = ");
      displayDistanceChange(
        dC.down / dCdx, 
        dC_creep.down / dCdx,
        programDesc.creepTime > 0);
    }

    Serial.print("dx (avg)  = ");
    displayDistanceChange(
        dC.avg / dCdx, 
        dC_creep.avg / dCdx,
        programDesc.creepTime > 0);   
    
    output.dx[trialID] = dC.avg / dCdx;
    output.dx_creep[trialID] = dC_creep.avg / dCdx;
  }

  changeVoltage(-programDesc.bipolarVoltage, 0);

  return output;
}

