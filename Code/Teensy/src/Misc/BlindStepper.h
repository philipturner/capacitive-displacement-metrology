#pragma once

#include <stdint.h>
#include "Diagnostics/CapacitanceTracker.h"

struct BlindStepper {
  enum class Mode {
    up = 0,
    down = 1,
    capacitance = 2,
  };

  BlindStepper();
  BlindStepper(uint32_t *attributes);

  void update();

private:
  Mode mode;
  float capacitanceThreshold; // units: pF
  uint32_t stepsPerCheck;

  // Start iteration for basing off the current sequence of steps.
  uint32_t startIterationID;
  bool measuringCapacitance;
};