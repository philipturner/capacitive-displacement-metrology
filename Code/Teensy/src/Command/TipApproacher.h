#pragma once

#include <stdint.h>

struct TipApproacher {
  enum class State {
    waitBeforeApproach = 0,
    approach = 1,
    stepUp = 2,
    stepDown = 3,
    feedback = 4,
  };

  TipApproacher();
  TipApproacher(State startingState);

  void updatePiezoZ();

private:
  State previousState;
  State currentState;
  uint32_t stateStartIterationID;
  bool didContact = false;
  bool skipRetractBeforeFeedback = false;

  uint32_t getIterationsSinceStateStart();
  void updateState();
  float getPiezoVoltage();
};