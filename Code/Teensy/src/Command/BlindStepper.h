#pragma once

#include "Command/Command.h"
#include "Diagnostics/CapacitanceTracker.h"

struct BlindStepper {
  enum class Mode {
    up = 0,
    down = 1,
    capacitance = 2,
  };

  enum class State {
    measuring = 0,
    retracting = 1,
    stepping = 2,
    finished = 3,
  };

  static constexpr uint32_t wavePeriod = 1200;

  BlindStepper();
  BlindStepper(Command command);
  State getCurrentState() const;

  void update();

private:
  Mode mode;
  float capacitanceThreshold; // units: pF
  uint32_t stepsPerCheck;

  State currentState;
  bool finishedRetracting = false;
  uint32_t waveStartIterationID = UINT32_MAX;

  uint32_t getIterationsSinceStart();
  float getRetractVoltage();
  float getStepWaveVoltage();
  void checkTipCrash() {
    
  }
};