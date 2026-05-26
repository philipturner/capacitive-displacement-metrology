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

  // Magnitude of accumulate(referenceSine * current) / n
  //
  // 65: -4.3e-12
  // 64: -1.1e-12
  // 63.8: -5e-13, -6.5e-13
  // 63.6: 5e-14
  // 63.4: 6e-13
  // 63: 2e12
  static constexpr float loopTimeLag = 63.6; // μs

  CapacitanceTracker();
  CapacitanceTracker(bool notDefaultConstructor);
  State getState(uint32_t iterationID);
  State getCurrentState() const;

  void update();

  float getBiasVoltage() const;

  // In the kilohertz loop, call this prior to reading from the ADC.
  void integrate(float current);

private:
  uint32_t startIterationID;
  State previousState;
  State currentState;

  float referenceStimulus;
  float referenceSine;
  float referenceCosine;
  void updateReferenceSignals();

  float previousCurrent = 0;
  int32_t zeroCrossingStartID;
  float zeroCrossingIterations;
  float sineAccumulator = 0;
  float cosineAccumulator = 0;
  uint32_t lockInSampleCount = 0;

  bool zeroCrossingFailed = false;
  float zeroCrossingAccumulator = 0;
  uint32_t zeroCrossingSampleCount = 0;
};