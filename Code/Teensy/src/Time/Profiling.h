#pragma once

#include <stdint.h>
#include <Arduino.h>

namespace Profiling {
  inline void display(uint32_t startCycles, uint32_t endCycles) {
    uint32_t dCycles = endCycles - startCycles;
    float dTime = float(dCycles) * 1.667e-3f;
    Serial.print(dTime, 3);
    Serial.print(" ");
  }
}