#pragma once

#include <stdint.h>

struct State {
  uint32_t modeStartIterationID = 0;

  float current = 0; // units: A
  float filteredCurrent = 0; // units: A

  float capacitance = 0; // units: pF
  float phaseShift = 0; // units: °
  uint32_t capacitanceUpdateCount = 0;

  float positionError = 0; // units: m
  float feedbackErrorTerm = 0; // units: m

  float biasVoltage = 0; // units: V
  float piezoXVoltage = 0; // units: V
  float piezoYVoltage = 0; // units: V
  float piezoZVoltage = 0; // units: V

private:
  // Delay line for 10 loop iterations.
  float currentSpike[10] = { 
    0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,
  };
  float filteredCurrentSpike = 0;
  float currentMaximum = 0;

public:
  void updateCurrent();

  void addSpike(float dV, float C);

  void updateCurrentSpike();

  float getPredictedCurrentSpike() const;

  // Retrieves the current maximum for usage in logging and resets it.
  float extractCurrentMaximum();

  uint32_t getTimeSinceModeStart();
};