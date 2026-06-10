#pragma once

#include <stdint.h>

struct Command {
  enum class Mode: uint8_t {
    idle = 0,

    // xAAA - X axis
    // yAAA - Y axis
    // zAAA - Z axis
    // bAAA - bias
    //
    // 992.1 Hz triangle wave, +/-AAA volts
    dacTest = 1,
    
    capacitanceReporting = 2,
    
    // uSSS - step up SSS times
    // dSSS - step down SSS times
    // cSSS,CCC - SSS steps per check, step up until capacitance > CCC fF
    blindStepping = 3,

    tipApproach = 4,

    idleFeedback = 5,

    // aFFF - auto; scale list in memory by factor of FFF
    // cVVV,ZZZ - custom; change bias to VVV volts, move ZZZ pm from setpoint
    spectroscopy = 6,

    // xFFF,AAA - x axis
    // yFFF,AAA - y axis
    //
    // ~FFF Hz scan wave, AAA nm peak to peak
    simpleScanning = 7,

    // iRRR,SSS - single image
    // vRRR,SSS - repeating video at single spot
    // dRRR,SSS - dual; video alternating between two spots
    //
    // RRRxRRR image, SSS nm width
    imaging = 8,

    // Temporarily force a mode to >10 to test new command parsing logic.
    placeholder1 = 9,
    placeholder2 = 10,
    placeholder3 = 11,

    // aN - dominant scan axis, 0 = x, 1 = y
    // lN - wait ~N μs for fixed time lag of electronics
    // oI,X,Y - center #I, position (X, Y) in nm
    // r - reset to defaults
    // sN - wait ~N ms for creep settling in dual video mode
    imagingSettings = 12,

    // TODO: Mode for changing the creep constants dynamically at runtine.
    // cX,Y - creep constants, in %/decade

    NUM_MODES = 13,
  };
  
  Mode mode = Mode::idle;

  char alphaCode = 0;
  
  float attributes[10];
};
