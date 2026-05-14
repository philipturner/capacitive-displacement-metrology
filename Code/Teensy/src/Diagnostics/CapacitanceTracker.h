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
  void update(float &capacitance, float &phaseShift);

private:
  uint32_t startIterationID;
  uint32_t startTrueTime;

  int32_t zeroCrossingStartID;
  int32_t zeroCrossingEndID;
  float sineSquaredAccumulator;
  float cosineSquaredAccumulator;
  uint32_t rmsCurrentSampleCount;

  void resetIntegrationVariables();
};