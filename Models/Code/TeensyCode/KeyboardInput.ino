#include "KeyboardInput.h"

#include "ADC.h"
#include "RingBuffer.h"
#include "TimeStatistics.h"

void timeFidelityDiagnosticLoop() {
  delay(500);

  Serial.println();
  Serial.println(timeStatistics.above1000000us_jumps);
  Serial.println(timeStatistics.above100000us_jumps);
  Serial.println(timeStatistics.above10000us_jumps);
  Serial.println(timeStatistics.above1000us_jumps);
  Serial.println(timeStatistics.above100us_jumps);
  Serial.println(timeStatistics.above20us_jumps);
  Serial.println(timeStatistics.exactly20us_jumps);
  Serial.println(timeStatistics.under20us_jumps);
  Serial.println(timeStatistics.total_jumps);
}

void adcResponsivenessDiagnosticLoop() {
  if (Serial.available() > 0) {
    char incomingByte = Serial.read();

    if (incomingByte == 'c') {
      Serial.println("received command 'c'");

      float voltage = ADC::readConversionCode();
      Serial.print("ADC code (fraction of full-scale): ");
      Serial.println(voltage, 6); // force it to 6 decimal places
    } else if (incomingByte == 'd') {
      Serial.println("received command 'd'");
      
      uint32_t rangeCode = ADC::readRangeSelect();
      Serial.print("Contents of range select register: ");
      Serial.println(rangeCode);
    } else if (incomingByte == '0') {
      Serial.println("received command '0'");
      
      ADC::writeRangeSelect(0b0000);
    } else if (incomingByte == '1') {
      Serial.println("received command '1'");
      
      ADC::writeRangeSelect(0b0001);
    }
  }
}

char oscilloscopeMode = '0';
float oscilloscopeCopiedSamples[1000];
uint32_t oscilloscopeAveragedGroupCount = 0;

void oscilloscopeGuardedCode(bool shouldDisplayLatest) {
  uint32_t previousSlotID = (oscilloscopeTimestamp - startTimestamp) / 20;
  uint32_t currentSlotID = (latestTimestamp - startTimestamp) / 20;

  if (shouldDisplayLatest) {
    // WARNING: Modulo operator may have undefined behavior for
    // negative integers. Force the number to be positive.
    int32_t endSlotID = currentSlotID + 1;
    int32_t startSlotID = endSlotID - 1000;
    endSlotID += 50000;
    startSlotID += 50000;
    if (startSlotID < 0) {
      Serial.println("Invalid slot ID.");
      exit(0);
    }

    for (int32_t slotID = startSlotID; slotID < endSlotID; ++slotID) {
      int32_t copiedSampleID = slotID - startSlotID;
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

  oscilloscopeTimestamp = latestTimestamp;
}

void oscilloscopeDiagnosticLoop() {
  delay(20);
  
  bool shouldDisplayLatest = false;
  bool shouldZoomIn = false;
  if (Serial.available() > 0) {
    char incomingByte = Serial.read();

    if (incomingByte == 'a') {
      oscilloscopeMode = 'a';
    } else if (incomingByte == 'l') {
      oscilloscopeMode = '0';
      shouldDisplayLatest = true;
    } else if (incomingByte == 'z') {
      oscilloscopeMode = '0';
      shouldDisplayLatest = true;
      shouldZoomIn = true;
    } else if (incomingByte == '0') {
      oscilloscopeMode = '0';
    }
  }
  
  // Make the guarded portion very small and do not
  // invoke 'Serial.print' here.
  oscilloscopeLock = true;
  oscilloscopeGuardedCode(shouldDisplayLatest);
  oscilloscopeLock = false;
  
  if (shouldDisplayLatest) {
    if (!shouldZoomIn) {
      for (uint32_t sampleID = 0; sampleID < 1000; ++sampleID) {
        float sample = oscilloscopeCopiedSamples[sampleID];
        Serial.print("voltage:");
        Serial.println(sample, 4);
      }
    } else {
      for (uint32_t sampleID = 0; sampleID < 100; ++sampleID) {
        float sample = oscilloscopeCopiedSamples[900 + sampleID];
        for (uint32_t i = 0; i < 10; ++i) {
          Serial.print("voltage:");
          Serial.println(sample, 4);
        }
      }
    }
  } else if (oscilloscopeMode == 'a') {
    uint32_t groupCount = oscilloscopeAveragedGroupCount;
    for (uint32_t groupID = 0; groupID < groupCount; ++groupID) {
      float minimum = oscilloscopeCopiedSamples[groupID * 3 + 0];
      float average = oscilloscopeCopiedSamples[groupID * 3 + 1];
      float maximum = oscilloscopeCopiedSamples[groupID * 3 + 2];

      Serial.print("min:");
      Serial.print(minimum, 4);
      Serial.print(",");

      Serial.print("avg:");
      Serial.print(average, 4);
      Serial.print(",");
      
      Serial.print("max:");
      Serial.println(maximum, 4);
    }
  }
}