#include <Arduino.h>
#include "Metrology.h"

void displayResult(Metrology::ProgramResult result, bool creepPart = false) {
  uint32_t trialCount = Metrology::ProgramResult::trialCount;
  for (uint32_t trialID = 0; trialID < trialCount; ++trialID) {
    float displacement;
    if (creepPart) {
      displacement = result.dx_creep[trialID];
    } else {
      displacement = result.dx[trialID];
    }

    Serial.print(displacement, 1);
    Serial.print(", ");
  }
}

void displayProgram(
  Metrology::ProgramDescriptor programDesc,
  Metrology::ProgramResult* rampResults, 
  uint32_t rampCount
) {
  Serial.print(programDesc.bipolarVoltage);
  Serial.print(", ");
  Serial.print(float(0));
  Serial.print(", ");
  
  for (uint32_t rampID = 0; rampID < rampCount; ++rampID) {
    Metrology::ProgramResult result = rampResults[rampID];
    displayResult(result);
  }
  Serial.println();

  if (programDesc.creepTime == 0) {
    return;
  }

  Serial.print(programDesc.bipolarVoltage);
  Serial.print(", ");
  Serial.print(programDesc.creepTime);
  Serial.print(", ");
  
  for (uint32_t rampID = 0; rampID < rampCount; ++rampID) {
    Metrology::ProgramResult result = rampResults[rampID];
    displayResult(result, true);
  }
  Serial.println();
}

void Metrology::multiRampProgram() {
  #if 1

  constexpr uint32_t rampCount = 1;
  constexpr uint32_t programCount = 5;

  // sampleCount = 10 (rampCount = 1)
  // sampleCount = 30 (rampCount = 2)
  float voltageSequence[programCount] = {
    52.5, 105, 210, 420, 420
  };
  float creepTimeSequence[programCount];
  for (uint32_t i = 0; i < programCount; ++i) {
    creepTimeSequence[i] = 0.0;
  }
  creepTimeSequence[programCount - 1] = 0.6;

  #elif 0

  constexpr uint32_t rampCount = 1;
  constexpr uint32_t programCount = 6;

  // sampleCount = 10
  float voltageSequence[programCount];
  for (uint32_t i = 0; i < programCount; ++i) {
    voltageSequence[i] = 420;
  };
  float creepTimeSequence[programCount] = {
    0.01, 0.15, 0.3, 0.6, 1.2, 0.0
  };

  #else

  constexpr uint32_t rampCount = 1;
  constexpr uint32_t programCount = 1;

  float voltageSequence[programCount] = {
    420
  };
  float creepTimeSequence[programCount] = {
    0.6
  };

  #endif

  ProgramResult* results = (ProgramResult *)malloc(
    rampCount * programCount * sizeof(ProgramResult));

  for (uint32_t rampID = 0; rampID < rampCount; ++rampID) {
    for (uint32_t programID = 0; programID < programCount; ++programID) {
      float voltage = voltageSequence[programID];
      float creepTime = creepTimeSequence[programID];
      
      ProgramDescriptor programDesc;
      programDesc.logSingleSamples = creepTime > 0;
      programDesc.verboseDriftCancellation = true;
      programDesc.bipolarVoltage = voltage;
      programDesc.creepTime = creepTime;

      ProgramResult result = metrologyProgram(programDesc);
      results[programID * rampCount + rampID] = result;
    }
  }

  Serial.println();

  for (uint32_t programID = 0; programID < programCount; ++programID) {
    float voltage = voltageSequence[programID];
    float creepTime = creepTimeSequence[programID];
    
    ProgramDescriptor programDesc;
    programDesc.logSingleSamples = creepTime > 0;
    programDesc.verboseDriftCancellation = true;
    programDesc.bipolarVoltage = voltage;
    programDesc.creepTime = creepTime;

    displayProgram(
      programDesc,
      results + programID * rampCount,
      rampCount);
  }

  free(results);
}