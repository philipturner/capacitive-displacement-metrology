#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Metrology/Metrology.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

Metrology metrology;

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();

  Metrology::Descriptor descriptor;
  descriptor.mode = Metrology::Mode::basicMeasurement;
  descriptor.logSingleSamples = false;
  descriptor.verboseDriftCancellation = true;
  descriptor.bipolarDriveVoltage = 96;

  metrology = Metrology(descriptor);

  /*
  if (!(CDC::readRegister(AD7745_STATUS) & 0b00000100)) {
    Serial.println("A previous measurement was queued.");
    exit(0);
  }

  // Assumes CAPCHOP is enabled, otherwise the delay is more than necessary.
  CDC::writeConfiguration(AD7745_MD_SINGLE_CONV);
  delay(115);

  if (CDC::readRegister(AD7745_STATUS) & 0b00000100) {
    Serial.println("Measurement is not ready.");
    exit(0);
  }

  float capacitance = CDC::readCapacitance();
  Serial.print("capacitance:");
  Serial.print(capacitance, 6);
  Serial.println();
  */
}

void loop() {
  metrology.loop();
}
