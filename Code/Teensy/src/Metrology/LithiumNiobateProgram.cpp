#include <Arduino.h>
#include "Metrology.h"

void displayResult(Metrology::ProgramResult result, bool creepPart = false) {
  uint32_t trialCount = Metrology::ProgramResult::trialCount;
  for (uint32_t trialID = 0; trialID < 3; ++trialID) {
    float displacement;
    if (creepPart) {
      displacement = result.dx_creep[trialID];
    } else {
      displacement = result.dx[trialID];
    }

    Serial.print(displacement, 1);
    Serial.print(", ")
  }
}

void Metrology::lithiumNiobateProgram() {
  constexpr uint32_t rampCount = 2;
  constexpr uint32_t voltageCount = 4;
  constexpr float creepTime = 0.3;

  float voltageSequence[voltageCount] = {
    52.5, 105, 210, 420
  };

  ProgramResult results[9];

  for (uint32_t rampID = 0; rampID < rampCount; ++rampID) {
    for (uint32_t programID = 0; programID < voltageCount; ++programID) {
      ProgramDescriptor programDesc;
      programDesc.logSingleSamples = false;
      programDesc.verboseDriftCancellation = true;
      programDesc.bipolarVoltage = voltageSequence[programID];
      programDesc.creepTime = 0;

      ProgramResult result = metrologyProgram(programDesc);
      results[programID * rampCount + rampID] = result;
    }
  }

  {
    ProgramDescriptor programDesc;
    programDesc.logSingleSamples = true;
    programDesc.verboseDriftCancellation = true;
    programDesc.bipolarVoltage = 420;
    programDesc.creepTime = creepTime;

    ProgramResult result = metrologyProgram(programDesc);
    results[voltageCount * rampCount] = result;
  }

  Serial.println();

  for (uint32_t programID = 0; programID < voltageCount; ++programID) {
    Serial.print(voltageSequence[programID]);
    Serial.print(", ");
    Serial.print(float(0));
    Serial.print(", ");
    
    for (uint32_t rampID = 0; rampID < rampCount; ++rampID) {
      ProgramResult result = results[programID * rampCount + rampID];
      displayResult(result);
    }

    Serial.println();
  }

  {
    ProgramResult result = results[voltageCount * rampCount];

    Serial.print(float(420));
    Serial.print(", ");
    Serial.print(float(0));
    Serial.print(", ");

    displayResult(result, false);

    Serial.print(float(420));
    Serial.print(", ");
    Serial.print(float(creepTime));
    Serial.print(", ");

    displayResult(result, true);

    Serial.println();
  }
}