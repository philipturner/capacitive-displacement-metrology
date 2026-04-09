#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Metrology/Metrology.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

Metrology::Mode currentMode;
Metrology metrology;

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();

  currentMode = Metrology::Mode::basicMeasurement;

  Metrology::Descriptor descriptor;
  descriptor.mode = currentMode;
  metrology = Metrology(descriptor);
}

void programBody() {
  #if 1
  constexpr uint32_t voltageCount = 4;

  float voltageSequence[voltageCount] = {
    52.5, 105, 210, 420
  };

  for (uint32_t programID = 0; programID < voltageCount; ++programID) {
      Metrology::ProgramDescriptor programDesc;
      programDesc.logSingleSamples = false;
      programDesc.verboseDriftCancellation = false;
      programDesc.bipolarVoltage = voltageSequence[programID];
      programDesc.creepTime = 0.01;

      metrology.metrologyProgram(programDesc);
    }

  /*
  Metrology::ProgramDescriptor programDesc;
  programDesc.logSingleSamples = true;
  programDesc.verboseDriftCancellation = true;
  programDesc.bipolarVoltage = 52.5;
  programDesc.creepTime = 0.3;

  metrology.metrologyProgram(programDesc);
  */

  #else

  metrology.lithiumNiobateProgram();

  #endif
}

void loop() {
  if (Serial.available() > 0) {
    char incomingByte = Serial.read();

    if (incomingByte == 'm') {
      if (currentMode != Metrology::Mode::metrology) {
        currentMode = Metrology::Mode::metrology;

        Metrology::Descriptor descriptor;
        descriptor.mode = currentMode;
        metrology = Metrology(descriptor);

        programBody();
      }
    }
  }

  metrology.loop();
}
