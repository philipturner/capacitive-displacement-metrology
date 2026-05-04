#include "TimeStatistics.h"
#include <Arduino.h>

void TimeStatistics::display() {
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