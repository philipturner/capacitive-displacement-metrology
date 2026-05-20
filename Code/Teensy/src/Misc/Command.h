#pragma once

#include <stdint.h>

struct Command {
  enum class Mode {
    // Set all DAC lines to zero and do nothing.
    idle = 0,

    biasTriangleWave = 1,
    
    capacitanceReporting = 2,
    
    // uXXXX - step up XXXX times
    // dXXXX - step down XXXX times
    // cXXXX,YYYY - step up until capacitance > XXX.X fF, YYYY steps per check
    //
    // There is an anti-spam mechanism to prevent this from activating until
    // the mode has been set to idle.
    blindStepping = 3,

    // Approach the surface with woodpecker algorithm. For now, immediately
    // retract and step backward after detecting tunneling current.
    tipApproach = 4,
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

private:
  static bool registerCommand(Command command);

public:
  static void throwError(
    const char *buffer, 
    const char *reason,
    int32_t number1 = 0,
    int32_t number2 = 0);
};