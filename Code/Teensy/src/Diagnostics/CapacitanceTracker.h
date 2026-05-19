#pragma once

#include <stdint.h>

struct CapacitanceTracker {
  enum class State {
    waiting = 0,
    measuring = 1,
    finished = 2,
  };

  static constexpr uint32_t wavePeriod = 1008;
  static constexpr uint32_t waveCountPre = 1;
  static constexpr uint32_t waveCountPost = 10;
  static constexpr float stimulusAmplitude = 12;

  CapacitanceTracker();
  CapacitanceTracker(bool notDefaultConstructor);
  State getState(uint32_t iterationID);
  State getCurrentState() const;
  void update(float &capacitance, float &phaseShift);

  float getBiasVoltage() const;
  void integrate(float current);

private:
  uint32_t startIterationID;
  State previousState;
  State currentState;

  float referenceSine;
  float referenceCosine;
  void updateReferenceSignals();

  float previousCurrent = 0;
  int32_t zeroCrossingStartID;
  float zeroCrossingIterations;
  float sineSquaredAccumulator = 0;
  float cosineSquaredAccumulator = 0;
  uint32_t lockInSampleCount = 0;

  bool zeroCrossingFailed = false;
  float zeroCrossingAccumulator = 0;
  uint32_t zeroCrossingSampleCount = 0;
};