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

  Metrology::Descriptor descriptor;
  descriptor.mode = Metrology::Mode::basicMeasurement;
  metrology = Metrology(descriptor);
}

void loop() {
  metrology.loop();
}
