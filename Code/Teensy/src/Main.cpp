#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Metrology/Metrology.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();
}

uint32_t periodID = 0;

void loop() {
  delay(3000);

  float voltages[7] = {
    10, 5, 2.5, 0, -2.5, -5, -10
  };

  float dacVoltage = voltages[periodID % 7];
  DAC1::writeVoltage(1, dacVoltage);
  DAC1::writeVoltage(3, dacVoltage);
  DAC1::writeVoltage(2, dacVoltage);

  periodID += 1;
}
