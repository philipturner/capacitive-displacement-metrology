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
void resetToMeasurement();

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();

  resetToMeasurement();
}

void resetToMeasurement() {
  currentMode = Metrology::Mode::basicMeasurement;

  Metrology::Descriptor descriptor;
  descriptor.mode = currentMode;
  metrology = Metrology(descriptor);
}

void programBody() {
  #if 0
  Metrology::ProgramDescriptor programDesc;
  programDesc.logSingleSamples = true;
  programDesc.verboseDriftCancellation = true;
  programDesc.bipolarVoltage = 100;
  programDesc.creepTime = 0.0;

  metrology.metrologyProgram(programDesc);

  #else
  
  metrology.multiRampProgram();

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

    if (incomingByte == 'b') {
      if (currentMode == Metrology::Mode::metrology) {
        resetToMeasurement();
      }
    }
  }

  metrology.loop();
}