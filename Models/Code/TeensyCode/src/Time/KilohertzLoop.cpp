#include <Arduino.h>
#include "../IC/ADC.h"
#include "KilohertzLoop.h"
#include "RingBuffer.h"

void kilohertzLoop() {
  if (oscilloscopeLock) {
    // Never encountered this after about a minute of testing,
    // although the code guarded by the lock was very small.
    //
    // You must include the 20 ms delay at the start of the
    // oscilloscope loop. Otherwise, this early return will
    // get hit roughly 10% of the time.
    return;
  }

  uint32_t currentTimestamp = micros();
  uint32_t previousTimestamp = latestTimestamp;
  latestTimestamp = currentTimestamp;
  float timeSeconds = float(currentTimestamp - startTimestamp);
  timeSeconds /= float(1000000);

  // Get the ADC data as soon as possible.
//   float voltage = ADC::readConversionCode();
//   voltage = 2 * voltage - 1;
//   voltage *= 12.288;
  
  // 1 kHz artificial sine wave for testing.
  float voltage = sin(2 * M_PI * 1000 * timeSeconds);
  voltage *= 10;
  
  uint32_t startSlotID = (previousTimestamp - startTimestamp) / 20;
  startSlotID += 1;
  uint32_t endSlotID = (currentTimestamp - startTimestamp) / 20;
  endSlotID += 1;
  if (endSlotID - startSlotID > 100) {
    Serial.println("Function was overloaded with work.");
    exit(0);
  }

  for (uint32_t slotID = startSlotID; slotID < endSlotID; ++slotID) {
    ringBuffer.samples[slotID % 50000] = voltage;
  }
}