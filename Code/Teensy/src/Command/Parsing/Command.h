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
    // cVVV,ZZZ - custom; change bias to VVV mV, move ZZZ pm from setpoint
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

    // aN - dominant scan axis, 0 = x, 1 = y
    // lN - wait ~N μs for fixed time lag of electronics
    // oI,X,Y - center #I, position (X, Y) in nm
    // r - reset to defaults
    // sN - wait ~N ms for creep settling
    imagingSettings = 9,

    // cCCC - set creep constant for both axes
    // r - reset accumulated drift
    // xCCC - set creep constant for X only
    // yCCC - set creep constant for Y only
    creepSettings = 10,

    // cDDD - calculate; move DDD nm to measure
    // tXXX, YYY - set slope for each axis
    tilt = 11,

    NUM_MODES = 12,
  };
  
  Mode mode = Mode::idle;

  char alphaCode = 0;
  
  float attributes[10];
};
