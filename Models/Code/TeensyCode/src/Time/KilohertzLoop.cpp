#include <Arduino.h>
#include "KilohertzLoop.h"
#include "Oscilloscope.h"

void oscilloscopeCycle(uint32_t previousTimestamp);

void kilohertzLoop() {
  if (kilohertzLoopLock) {
    // Never encountered this after about a minute of testing,
    // although the code guarded by the lock was very small.
    //
    // You must include the 20 ms delay at the start of the
    // any asynchronous loop that grabs the lock. Otherwise,
    // this early return will get hit roughly 10% of the time.
    return;
  }

  uint32_t currentTimestamp = micros();
  uint32_t previousTimestamp = latestTimestamp;
  latestTimestamp = currentTimestamp;
  
  kilohertzLoopBody(previousTimestamp);
}

void oscilloscopeSamplingCycle(uint32_t previousTimestamp) {
  uint32_t startSlotID = (previousTimestamp - startTimestamp) / 20;
  startSlotID += 1;
  uint32_t endSlotID = (latestTimestamp - startTimestamp) / 20;
  endSlotID += 1;
  if (endSlotID - startSlotID > 100) {
    Serial.println("Function was overloaded with work.");
    exit(0);
  }

  #if 0
  // Get the ADC data as soon as possible.
  float voltage = ADC::readConversionCode();
  voltage = 2 * voltage - 1;
  voltage *= 12.288;
  #else
  float timeSeconds = float(latestTimestamp - startTimestamp);
  timeSeconds /= float(1000000);

  // 1 kHz artificial sine wave for testing.
  float voltage = sin(2 * M_PI * 1000 * timeSeconds);
  voltage *= 10;
  #endif

  #if USE_RING_BUFFER
  for (uint32_t slotID = startSlotID; slotID < endSlotID; ++slotID) {
    ringBuffer.samples[slotID % 50000] = voltage;
  }
  #endif
}