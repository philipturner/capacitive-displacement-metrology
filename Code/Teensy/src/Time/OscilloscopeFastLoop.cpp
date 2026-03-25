#include "IC/ADC.h"
#include "KilohertzLoop.h"
#include "Oscilloscope.h"

void Oscilloscope::fastLoop() {
  uint32_t start = KilohertzLoop::startTimestamp;
  uint32_t previous = KilohertzLoop::previousTimestamp;
  uint32_t latest = KilohertzLoop::latestTimestamp;
  uint32_t period = KilohertzLoop::period;

  uint32_t startSlotID = (previous - start) / period;
  uint32_t endSlotID = (latest - start) / period;
  if (endSlotID - startSlotID >= OSCILLOSCOPE_HISTORY_SIZE) {
    Serial.println("Function was overloaded with work.");
    exit(0);
  }

  #if 1
  // Get the ADC data as soon as possible.
  ADCOutputConversion result = ADC::readVoltage();
  float voltage = result.floatValue;
  voltage = 2 * voltage - 1;
  voltage *= 12.288;
  #else

  // 1 kHz artificial sine wave for testing.
  float timeSeconds = float(latest - start) / float(1e6);
  float voltage = sin(2 * M_PI * 1000 * timeSeconds);
  voltage *= 10;
  #endif

  for (uint32_t slotID = startSlotID + 1; slotID <= endSlotID; ++slotID) {
    uint32_t wrappedSlotID = slotID % OSCILLOSCOPE_HISTORY_SIZE;
    ringBuffer[wrappedSlotID] = voltage;
  }
}

void _oscilloscopeFastLoop() {
  Oscilloscope::_global->fastLoop();
}

void Oscilloscope::startFastLoop(Oscilloscope* global) {
  Oscilloscope::_global = global;
  KilohertzLoop::initialize(_oscilloscopeFastLoop, 20);
}