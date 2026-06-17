#pragma once

#include <stdint.h>

struct TipApproacher {
  static constexpr bool forceModeChanges = false;

  enum class State {
    waitBeforeApproach = 0,
    approach = 1,
    stepUp = 2,
    stepDown = 3,
    feedback = 4,
  };

  TipApproacher();
  TipApproacher(State startingState, bool didContact);
  static State rangeRestorationState();
  static bool modeShouldChange();
  static void forceModeChange();

  void update();

private:
  State currentState;
  bool didContact;
  uint32_t stateStartIterationID;

  uint32_t getIterationsSinceStateStart();
  void updateState();
  float getPiezoVoltage();
};