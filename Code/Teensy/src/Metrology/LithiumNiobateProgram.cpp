#include <Arduino.h>
#include "Metrology.h"

void Metrology::lithiumNiobateProgram() {
  /*
  descriptor.logSingleSamples = false;
  descriptor.verboseDriftCancellation = true;
  descriptor.bipolarDriveVoltage = 420;
  descriptor.cdcCapdacCode = 20;
  descriptor.creepTime = 0.3;
  */

  constexpr uint32_t rampCount = 2;
  constexpr uint32_t voltageCount = 4;

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
    programDesc.creepTime = 0.3;

    ProgramResult result = metrologyProgram(programDesc);
    results[voltageCount * rampCount] = result;
  }

  
}