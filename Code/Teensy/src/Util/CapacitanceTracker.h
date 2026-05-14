#include <stdint.h>

class CapacitanceTracker {
  static constexpr uint32_t wavePeriod = 1008;
  static constexpr uint32_t waveCount = 10;
  static constexpr float stimulusAmplitude = 12;

  CapacitanceTracker();
  void update(float &capacitance, float &phaseShift);

private:
  uint32_t startIterationID;
  uint32_t startTrueTime;

  int32_t zeroCrossingStartID;
  int32_t zeroCrossingEndID;
  float sineSquaredAccumulator;
  float cosineSquaredAccumulator;
  uint32_t rmsCurrentSampleCount;
};