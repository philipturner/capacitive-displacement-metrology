#pragma once

#include <stdint.h>

struct TipApproacher {
  enum class State {
    
  };

  TipApproacher();
  TipApproacher(bool notDefaultConstructor);

  void update();

  void writeToLog(uint32_t slotID);

private:
  State previousState;
  State currentState;
  uint32_t stateStartIterationID; // remove entirely
  float positionError = 0;

  uint32_t getTimeSinceStateStart();
  void updateState();
  void updateDACs();
};