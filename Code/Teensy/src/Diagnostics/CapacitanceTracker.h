#pragma once

#include "Time/KilohertzLoop.h"

struct CapacitanceTracker {
  enum class State {
    waiting = 0,
    measuring = 1,
    finished = 2,
  };

  static constexpr uint32_t wavePeriod = KilohertzLoopRound(1000);
  static constexpr uint32_t waveCountPre = 1;
  static constexpr uint32_t waveCountPost = 10;
  static constexpr float stimulusAmplitude = 12;

  // Fine-tune this by checking the ratio of sineMixed / cosineMixed and
  // zeroing it out.
  //
  // Adding the piezos into the loop would theoretically add <10 μs
  // 2.65 kHz, Q = 18 (higher Q is faster):
  // 3.337 μs [0-43 Hz]
  // 3.350 μs [170 Hz]
  // 3.507 μs [580 Hz]
  // 4.000 μs [1080 Hz]
  // 5.050 μs [1544 Hz]
  // 0.570 μs lag from PA95 with 280 kHz bandwidth at |gain| = 35.7
  static constexpr float loopTimeLag = 87; // μs

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