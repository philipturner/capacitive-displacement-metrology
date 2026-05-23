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

  // Tunneling barrier height is not known precisely from the literature.
  // Supposedly, ambient contamination lowers it from 4.0-4.5 V in vacuum
  // to 0.5-1.2 V under ambient conditions.
  //
  // 4.0 V -> 112 pm per decade
  // 1.0 V -> 225 pm per decade
  // 0.5 V -> 318 pm per decade
  static constexpr float tunnelingBarrierHeight = 1.0;

  // 100 ms: one 5 nA and one 4 nA spike
  // 30 ms: no crashes reported
  // 10 ms: no crashes reported
  // 3 ms: no crashes reported
  // 1 ms: no capacitive spikes registered as over 5 nA
  // 300 μs: looks like capacitive spike after tip approach
  // 100 μs: a few crashes
  // 30 μs: rapid crashing
  static constexpr uint32_t integratorTimeLag = 10000; // μs
  
  TipApproacher();
  TipApproacher(bool notDefaultConstructor);

  void update();

  void writeToLog(uint32_t slotID);

private:
  State previousState;
  State currentState;
  uint32_t stateStartIterationID;

  float feedback_diagnostic1 = 0;
  float feedback_diagnostic2 = 0;

  uint32_t getTimeSinceStateStart();
  void updateState();
  void updateDACs();
};