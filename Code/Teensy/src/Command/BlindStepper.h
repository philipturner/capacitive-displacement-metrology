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
    stepping = 1,
    finished = 2,
  };

  static constexpr float restPosition = -270;
  static constexpr float stepUpAmplitude = 400;
  static constexpr float stepDownAmplitude = 200;

  BlindStepper();
  BlindStepper(Command command);
  State getCurrentState() const;

  void update(uint32_t targetWavePeriod, bool skipMeasure = false);

private:
  Mode mode;
  float capacitanceThreshold; // units: pF
  uint32_t stepsPerCheck;

  State currentState;
  uint32_t cycleID = 0;
  uint32_t waveStartIterationID = UINT32_MAX;

  float sawtoothWave(uint32_t waveIterationDelta, uint32_t wavePeriod);
  void checkStartIterationValid();
};