#pragma once

#include <stdint.h>

struct Command {
  enum class Mode: uint8_t {
    idle = 0,

    // xXXX - X axis
    // yXXX - Y axis
    // zXXX - Z axis
    // bXXX - bias
    //
    // 1008 Hz triangle wave, +/-XXX volts
    dacTest = 1,
    
    capacitanceReporting = 2,
    
    // uXXXX - step up XXXX times
    // dXXXX - step down XXXX times
    // cXXXX,YYYY - step up until capacitance > XXX.X fF, YYYY steps per check
    blindStepping = 3,

    tipApproach = 4,
  };
  Mode mode = Mode::idle;
  char alphaCode = 0;
  uint32_t attributes[10];
};

struct CommandTracker {
  static inline char buffer[51];

  // Tells the fast loop whether the slow loop was interrupted while updating
  // the latest command.
  static inline bool lock = false;

  // Reject future commands until the latest one is acknowledged.
  static inline uint32_t latestCommandID = 0;
  static inline uint32_t acknowledgedCommandID = 0;
  static inline Command latestCommand;

  static void processSerialInput();

private:
  static bool registerCommand(Command command);

public:
  static void throwError(
    const char *reason,
    int32_t number1 = 0,
    int32_t number2 = 0);

  // This is for the fast loop to invoke.
  static bool nextCommand(Command &nextCommand);
};