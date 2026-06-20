#pragma once

#include "Command.h"

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

  static bool registerCommand(Command command);

  // This is for the fast loop to invoke.
  static bool nextCommand(Command &nextCommand);

  static void bounceError(
    const char *reason,
    int32_t number1 = 0,
    int32_t number2 = 0);

  static void throwError(
    const char *reason,
    int32_t number1 = 0,
    int32_t number2 = 0);  
};