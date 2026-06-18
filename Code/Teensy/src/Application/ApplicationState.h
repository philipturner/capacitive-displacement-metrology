#pragma once

#include "Util/Vector/Vector.h"
#include <stdint.h>

struct ApplicationState {
  // TODO: Functionality to simulate a surface and constexpr bool to enable it.

  uint32_t modeStartIterationID = 0;

  float current = 0; // units: A
  float filteredCurrent = 0; // units: A

  float capacitance = 0; // units: F
  float phaseShift = 0; // units: °
  uint32_t capacitanceUpdateCount = 0;

  float spectroscopyTrigger = 0;

  float biasVoltage = 0; // units: V
  float piezoXVoltage = 0; // units: V
  float piezoYVoltage = 0; // units: V
  float piezoZVoltage = 0; // units: V

  float4 abbreviated() const {
    float4 output;
    output.x = piezoXVoltage;
    output.y = piezoYVoltage;
    output.z = piezoZVoltage;
    output.w = filteredCurrent;
    return output;
  }

private:
  // Delay line for 10 loop iterations.
  float currentSpike[10] = { 
    0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,
  };
  float filteredCurrentSpike = 0;
  float currentMaximum = 0;

  void updateCurrentSpike();

public:
  void updateCurrent(bool useADC);

  void addSpike(float dV, float C);

  float getPredictedCurrentSpike() const;

  // Retrieves the current maximum for usage in logging and resets it.
  float extractCurrentMaximum();

  uint32_t getTimeSinceModeStart();
};