#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
#include "IC/ADC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Misc/Application.h"
#include "Time/KilohertzLoop.h"
#include <Arduino.h>

float latestADCVoltage = 0;

void kilohertzLoop();

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Log::initialize();
  KilohertzLoop::initialize(kilohertzLoop, 12);
}

void loop() {
  delay(50);

  if (ErrorMessage::hasError()) {
    ErrorMessage::nullTerminate();

    Serial.println();
    Serial.println("error message:");
    Serial.println(ErrorMessage::buffer);
    return;
  }

  float t = float(micros()) / 1e6;
  Serial.print("t = ");
  Serial.print(t, 3);
  Serial.print(" s");

  Serial.print(" | ADC voltage = ");
  Serial.print(latestADCVoltage, 4);
  Serial.println();
}

void kilohertzLoop() {
  PA95::writeVoltage(1, 0.0);
  PA95::writeVoltage(2, 0.0);
  PA95::writeVoltage(3, 0.0);

  auto conversion = ADC::readVoltage();
  latestADCVoltage = conversion.voltage;
}