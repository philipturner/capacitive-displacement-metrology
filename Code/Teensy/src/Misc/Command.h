#pragma once

#include <stdint.h>

struct Command {
  enum class Mode {
    idle = 0,
    error = 1, // spam error message and wait for new command
    biasTriangleWave = 2,
    capacitanceReporting = 3,
    
    // uXXXX - step up XXXX times
    // dXXXX - step down XXXX times
    // cXXXX,YYYY - step up until capacitance > XXXX fF, YYYY steps per check
    //
    // There is an anti-spam mechanism to prevent this from activating until
    // the mode has been set to idle.
    blindStepping = 4,

    // Approach the surface with woodpecker algorithm. For now, immediately
    // retract and step backward after detecting tunneling current.
    tipApproach = 5,
  };
  Mode mode = Mode::idle;
  uint32_t attributes[10];
};

struct CommandTracker {
  // Tells the fast loop whether the slow loop was interrupted while updating
  // the latest command.
  static inline bool lock = false;

  // Reject future commands until the latest one is acknowledged.
  static inline uint32_t latestCommandID = 0;
  static inline uint32_t acknowledgedCommandID = 0;
  static Command latestCommand;

  static void processSerialInput();
};