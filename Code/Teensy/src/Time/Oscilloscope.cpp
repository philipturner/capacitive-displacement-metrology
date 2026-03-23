#include "IC/ADC.h"
#include "KilohertzLoop.h"
#include "Oscilloscope.h"

void Oscilloscope::initialize() {
  ADC::writeRangeSelect(0b0000);
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

  }
}

/*

// MARK: - Oscilloscope Guarded Code

#if USE_OSCILLOSCOPE
char oscilloscopeMode = '0';
float oscilloscopeCopiedSamples[1000];
uint32_t oscilloscopeAveragedGroupCount = 0;
uint32_t oscilloscopeCopiedTimestamp;

void oscilloscopeGuardedCode(bool shouldCopyLatest) {
  uint32_t previousSlotID = (oscilloscopeTimestamp - startTimestamp) / 20;
  uint32_t currentSlotID = (latestTimestamp - startTimestamp) / 20;

  if (shouldDisplayLatest) {
    // WARNING: Modulo operator may have undefined behavior for
    // negative integers. Force the number to be positive.
    int32_t endSlotID = currentSlotID + 1;
    int32_t startSlotID = currentSlotID + 1 - 1000;
    endSlotID += 50000;
    startSlotID += 50000;
    if (startSlotID < 0) {
      Serial.println("Invalid slot ID.");
      exit(0);
    }

    for (int32_t slotID = startSlotID; slotID < endSlotID; ++slotID) {
      int32_t copiedSampleID = slotID - startSlotID;
      // Instead of forcing to positive, just do (slotID + 100) % 100 here.
      float sample = ringBuffer.samples[slotID % 50000];
      oscilloscopeCopiedSamples[copiedSampleID] = sample;
    }
  } else if (oscilloscopeMode == 'a') {
    // Average every group of 50 samples as it gets completed.
    // A group is in progress if modulo previousSlotID = 0...49.
    uint32_t previousInProgressID = previousSlotID / 50;
    uint32_t currentInProgressID = currentSlotID / 50;
    if (currentInProgressID - previousInProgressID > 900) {
      Serial.println("Buffer overflow, in-progress data may wrap around and overwrite finished groups.");
      exit(0);
    }
    if (currentInProgressID - previousInProgressID > 300) {
      Serial.println("Buffer overflow, exceeded buffer size allocated for copied samples.");
      exit(0);
    }

    for (
      uint32_t groupID = previousInProgressID;
      groupID < currentInProgressID;
      ++groupID
    ) {
      uint32_t copiedGroupID = groupID - previousInProgressID;

      float minimum = 1e38;
      float sum = 0;
      float maximum = -1e38;
      for (uint32_t indexInGroup = 0; indexInGroup < 50; ++indexInGroup) {
        uint32_t slotID = groupID * 50 + indexInGroup;
        float sample = ringBuffer.samples[slotID % 50000];

        minimum = min(minimum, sample);
        sum += sample;
        maximum = max(maximum, sample);
      }
      float average = sum / 50;

      oscilloscopeCopiedSamples[copiedGroupID * 3 + 0] = minimum;
      oscilloscopeCopiedSamples[copiedGroupID * 3 + 1] = average;
      oscilloscopeCopiedSamples[copiedGroupID * 3 + 2] = maximum;
    }

    oscilloscopeAveragedGroupCount =
    currentInProgressID - previousInProgressID;
  }

  oscilloscopeCopiedTimestamp = latestTimestamp;
}

uint32_t staticDisplayTimeNext = 0;
bool getShouldDisplayLatest() {
  if (oscilloscopeTimestamp >= staticDisplayTimeNext) {
    staticDisplayTimeNext = max(
      oscilloscopeCopiedTimestamp, staticDisplayTimeNext + 1000000);
    return true;
  }
  return false;
}
#endif // USE_OSCILLOSCOPE

// MARK: - Oscilloscope Display Loop

void oscilloscopeDisplayLoop() {
  delay(20);

  bool shouldCopyLatest = false;
  if (Serial.available() > 0) {
    char incomingByte = Serial.read();

    if (incomingByte == 'a') {
      oscilloscopeMode = 'a';
    } else if (incomingByte == 'l') {
      oscilloscopeMode = 'l';
      shouldCopyLatest = true;
    } else if (incomingByte == 'z') {
      oscilloscopeMode = 'z';
      shouldCopyLatest = true;
    } else if (incomingByte == '0') {
      oscilloscopeMode = '0';
    }
  }
  
  // Make the guarded portion very small and do not
  // invoke 'Serial.print' here.
  oscilloscopeLock = true;
  oscilloscopeGuardedCode(shouldCopyLatest);
  oscilloscopeLock = false;

  if (shouldCopyLatest && getShouldDisplayLatest()) {
    if (oscilloscopeMode == 'l') {
      for (uint32_t sampleID = 0; sampleID < 1000; ++sampleID) {
        float sample = oscilloscopeCopiedSamples[sampleID];
        Serial.print(">voltage:");
        Serial.print(sampleID);
        Serial.print(":");
        Serial.println(sample, 4);
      }
    } else if (oscilloscopeMode == 'z') {
      for (uint32_t sampleID = 0; sampleID < 100; ++sampleID) {
        float sample = oscilloscopeCopiedSamples[900 + sampleID];
        for (uint32_t i = 0; i < 10; ++i) {
          Serial.print(">voltage:");
          Serial.print(sampleID * 10 + i);
          Serial.print(":");
          Serial.println(sample, 4);
        }
      }
    }

    Serial.print("current timestamp: ");
    Serial.println(oscilloscopeCopiedTimestamp);
    Serial.print("next display timestamp: ");
    Serial.println(staticDisplayTimeNext);
  }
  
  if (oscilloscopeMode == 'a') {
    uint32_t groupCount = oscilloscopeAveragedGroupCount;
    for (uint32_t groupID = 0; groupID < groupCount; ++groupID) {
      float minimum = oscilloscopeCopiedSamples[groupID * 3 + 0];
      float average = oscilloscopeCopiedSamples[groupID * 3 + 1];
      float maximum = oscilloscopeCopiedSamples[groupID * 3 + 2];

      Serial.print(">min:");
      Serial.println(minimum, 4);

      Serial.print(">avg:");
      Serial.println(average, 4);
      
      Serial.print(">max:");
      Serial.println(maximum, 4);
    }
  }
}

*/