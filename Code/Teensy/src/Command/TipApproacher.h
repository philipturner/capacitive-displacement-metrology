#pragma once

#include <stdint.h>

struct TipApproacher {
  enum class State {
    preWait = 0,
    wait = 1,
    approach = 2,
    preStep = 3,
    stepAndWait = 4,
    retract = 5,
    finished = 6,
  };

  TipApproacher();
  TipApproacher(bool notDefaultConstructor);

  void update();

private:
  State previousState;
  State currentState;
  uint32_t segmentStartIterationID;
  float preStepVoltage = 80;

  void updateState();
  uint32_t getIterationsSinceStart();
  float getPiezoVoltage();
};