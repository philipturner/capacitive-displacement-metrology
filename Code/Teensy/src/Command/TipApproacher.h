#pragma once

#include "Command/BlindStepper.h"
#include "Command/Command.h"

struct TipApproacher {
  enum class State {
    forwardStepping = 0,
    waiting = 1,
    approaching = 2,
    retracting = 3,
    feedback = 4,
  };

  static constexpr float setpointVoltage = 0.050;
  static constexpr float setpointCurrent = 100e-12;
  static constexpr uint32_t waitTime = 1000;
  static constexpr uint32_t retractTime = 1500;

  // -270 V -> 270 V, 0.32 nm/V, 1000 nm/s
  static constexpr uint32_t approachTime = 172800;

  // Tunneling barrier height is not known precisely from the literature.
  // Supposedly, ambient contamination lowers it from 4.0-4.5 V in vacuum
  // to 0.5-1.2 V under ambient conditions.
  //
  // 4.0 V -> 112 pm per decade
  // 1.0 V -> 225 pm per decade
  // 0.5 V -> 318 pm per decade
  static constexpr float tunnelingBarrierHeight = 1.0;
  static constexpr uint32_t integratorTimeLag = 1000;
  
  TipApproacher();

  void update();

private:
  State previousState;
  State currentState;
  uint32_t stateStartIterationID;

  BlindStepper blindStepper;

  uint32_t getTimeSinceStateStart();
  void updateState();
  void updateDACs();
};