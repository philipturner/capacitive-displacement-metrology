#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

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
