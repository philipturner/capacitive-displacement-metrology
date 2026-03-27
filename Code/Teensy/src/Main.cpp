#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Time/Oscilloscope.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();
}

void loop() {
  
}