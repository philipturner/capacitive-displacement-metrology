#pragma once

#include <stdint.h>

struct Feedback {
  enum class State {
    normal = 0,
    preStepUp = 1,
    stepUpAndWait = 2,
    preStepDown = 3,
    stepDownAndWait = 4,
  };

  static constexpr float setpointVoltage = 0.050;
  static constexpr float setpointCurrent = 10e-12;
  static constexpr float tunnelingBarrierHeight = 1.0;
  static constexpr uint32_t integratorTimeLag = 4000; // μs

  Feedback();
  Feedback(bool notDefaultConstructor);

private:
  State currentState;
  uint32_t stateStartIterationID;
  uint32_t getIterationsSinceStart();

  // minimum and maximum in V before stepping re-centers the range
  void updateState(float rangeMin, float rangeMax);
  void updatePiezoZ();
};