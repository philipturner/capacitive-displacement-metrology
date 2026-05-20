#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
#include "IC/ADC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Misc/Application.h"
#include "Time/KilohertzLoop.h"
#include "Util/FilterUtil.h"
#include <Arduino.h>

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

  Log::transmitBufferedSamples();
}

void kilohertzLoop() {
  PA95::writeVoltage(1, 0.0);
  PA95::writeVoltage(2, 0.0);
  PA95::writeVoltage(3, 0.0);

  {
    auto conversion = ADC::readVoltage();
    Application::state.current = -conversion.voltage / 1e9;

    float alpha = FilterUtil::getLowpassAlpha(10000, KilohertzLoop::period);
    Application::state.filteredCurrent *= 1 - alpha;
    Application::state.filteredCurrent += alpha * Application::state.current;
  }

  uint32_t iterationsPerLog = Log::targetLogPeriod / KilohertzLoop::period;
  if (KilohertzLoop::iterationID % iterationsPerLog == 0) {
    uint32_t ringIndex = Log::unsafeBufferedLogID % Log::logSize;

    Log::ringBuffers[0][ringIndex] = Application::state.filteredCurrent;
    Log::ringBuffers[1][ringIndex] = Application::state.piezoXVoltage;
    Log::ringBuffers[2][ringIndex] = Application::state.piezoYVoltage;
    Log::ringBuffers[3][ringIndex] = Application::state.piezoZVoltage;

    Log::unsafeBufferedLogID += 1;
  }
}