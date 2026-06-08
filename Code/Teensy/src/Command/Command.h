#pragma once

#include <stdint.h>

struct Command {
  enum class Mode: uint8_t {
    idle = 0,

    // xXXXX - X axis
    // yXXXX - Y axis
    // zXXXX - Z axis
    // bXXXX - bias
    //
    // 992.1 Hz triangle wave, +/-XXXX volts
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

    // xXXXX,YYYY - x axis
    // yXXXX,YYYY - y axis
    //
    // ~XXXX Hz scan wave, YYY.Y nm peak to peak
    // Z feedback active while scanning
    simpleScanning = 7,

    // iR,S - single image
    // vR,S - repeating video at single spot
    // dR,S - dual; video alternating between two spots
    //
    // R - resolution; number of pixels
    // S - size of image, in multiples of 0.1 nm
    imaging = 8,

    // Temporarily force a mode to >10 to test new command parsing logic.
    placeholder1 = 9,
    placeholder2 = 10,
    placeholder3 = 11,

    // aN - dominant scan axis, x = 0, y = 1
    // cI,X,Y - center #I, position (X, Y) * 0.1 nm
    // sN - wait ~N ms for creep settling in dual video mode
    // xNNN - x creep constant, N.NN%/decade
    // yNNN - y creep constant, N.NN%/decade
    imagingSettings = 12,

    NUM_MODES = 13,
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