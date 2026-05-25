#pragma once

#include <stdint.h>

struct State {
  float current = 0; // units: A
  float filteredCurrent = 0; // units: A
  float capacitance = 0; // units: pF
  float phaseShift = 0; // units: °

  float biasVoltage = 0; // units: V
  float piezoXVoltage = 0; // units: V
  float piezoYVoltage = 0; // units: V
  float piezoZVoltage = 0; // units: V

  bool tipCrashed = false;
  uint32_t lastBiasChangeIter = 0;
};