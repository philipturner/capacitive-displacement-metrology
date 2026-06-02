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

    idleFeedback = 5,

    // aXXXX - auto; use list of V,Z pairs stored in program memory, X.XXX = scale factor
    // cXXXX,YYYY - custom; change bias to XXXX mV, move YYYY pm from setpoint
    spectroscopy = 6,

    // xXXX,YYY - x axis
    // yXXX,YYY - y axis
    //
    // XXX Hz sine wave, +/-YYY volts
    // Z feedback active while scanning
    simpleScanning = 7,

    // iR,S,X,Y - single image
    // vR,S,X,Y - repeating video at single spot
    // dR,S,X,Y,X2,Y2 - dual; video alternating between two spots
    //
    // R - resolution; number of pixels
    // S - size of image
    // X,Y - origin; most negative coordinate of image bounds
    //
    // X, Y, S are multiples of 0.1 nm, limit of image bounds is +/-135.0 nm or
    // +/-1350 in the raw serial input.
    imaging = 8,

    NUM_MODES = 9,
  };
  Mode mode = Mode::idle;
  char alphaCode = 0;
  int32_t attributes[10];
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