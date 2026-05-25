#pragma once

#include <stdint.h>

struct TipApproacher {
  enum class State {
    waiting = 0,
    approaching = 1,
    feedback = 2,
  };

  static constexpr float setpointVoltage = 0.050;
  static constexpr float setpointCurrent = 100e-12;
  
  // -270 V -> 270 V, 0.32 nm/V, 1000 nm/s
  static constexpr uint32_t approachTime = 172800; // μs


  static constexpr uint32_t waitTime = 2000; // μs
  
  static constexpr uint32_t integratorTimeLag = 10000; // μs
  
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