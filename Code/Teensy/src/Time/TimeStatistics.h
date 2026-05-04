#pragma once

#include <stdint.h>
#include <Arduino.h>

struct TimeStatistics {
  static constexpr uint32_t binCount = 100;
  uint32_t bins[binCount]; // may cause program to fail to upload
  uint32_t largeJumpCount = 0;
  uint32_t totalJumpCount = 0;

  TimeStatistics() {
    for (uint32_t binID = 0; binID < binCount; ++binID) {
      bins[binID] = 0;
    }
  }

  void integrate(uint32_t jumpDuration, uint32_t period) {
    totalJumpCount += 1;
    if (totalJumpCount == 1) {
      return;
    }

    if (jumpDuration < binCount) {
      bins[jumpDuration] += 1;
    } else {
      largeJumpCount += 1;
    }
  }

  // Display the results.
  void display() {
    for (uint32_t binID = 0; binID < binCount; ++binID) {
      uint32_t jumpCount = bins[binID];
      if (jumpCount == 0) {
        continue;
      }

      if (binID < 10) {
        Serial.print(" ");
      }
      if (binID < 100) {
        Serial.print(" ");
      }
      Serial.print(binID);
      Serial.print(" μs: ");
      Serial.print(jumpCount);
      Serial.println();
    }

    if (largeJumpCount > 0) {
      Serial.print("over ");
      Serial.print(binCount);
      Serial.print(" μs: ");
      Serial.print(largeJumpCount);
      Serial.println();
    }

    Serial.print("total: ");
    Serial.print(totalJumpCount);
    Serial.println();
  }
};