#include "IC/ADC.h"
#include "KilohertzLoop.h"
#include "Oscilloscope.h"

void Oscilloscope::initialize() {
  ADC::writeRegister(ADS8689_RANGE_SEL_REG, 0b0000);
  ADC::nop(); // prepare for the first sample

  copiedTimestamp = UINT32_MAX;
  staticDisplayTimeNext = 0;
}

void Oscilloscope::slowLoop() {
  delay(20);

  // Make the guarded portion very small and do not
  // invoke 'Serial.print' here.
  KilohertzLoop::lock = true;
  copyData();
  KilohertzLoop::lock = false;

  if (!shouldDisplayData()) {
    return;
  }

  for (uint32_t slotID = 0; slotID < OSCILLOSCOPE_HISTORY_SIZE; ++slotID) {
    float voltage = copiedSamples[slotID];
    Serial.print(">voltage:");
    Serial.print(slotID);
    Serial.print(":");
    Serial.println(voltage, 4);
  }

  Serial.print("current timestamp: ");
  Serial.println(copiedTimestamp);
  Serial.print("next display timestamp: ");
  Serial.println(staticDisplayTimeNext);
}

void Oscilloscope::copyData() {
  uint32_t start = KilohertzLoop::startTimestamp;
  uint32_t latest = KilohertzLoop::latestTimestamp;
  uint32_t period = KilohertzLoop::period;

  int32_t endSlotID = (latest - start) / period;
  int32_t startSlotID = endSlotID - OSCILLOSCOPE_HISTORY_SIZE;

  for (int32_t slotID = startSlotID + 1; slotID <= endSlotID; ++slotID) {
    int32_t wrappedSlotID = slotID + OSCILLOSCOPE_HISTORY_SIZE;
    wrappedSlotID %= OSCILLOSCOPE_HISTORY_SIZE;
    float voltage = ringBuffer[wrappedSlotID];

    int32_t copiedSlotID = slotID - (startSlotID + 1);
    copiedSamples[copiedSlotID] = voltage;
  }

  copiedTimestamp = latest;
}

bool Oscilloscope::shouldDisplayData() {
  if (copiedTimestamp >= staticDisplayTimeNext) {
    staticDisplayTimeNext = max(
      copiedTimestamp, staticDisplayTimeNext + 1000000);
    return true;
  } else {
    return false;
  }
}
