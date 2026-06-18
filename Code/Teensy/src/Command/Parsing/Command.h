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

    // a - calculate tilt during imaging; set tilt to 0
    // x - set for X axis
    // y - set for Y axis
    //
    // tilt samples are pushed the moment the relevant pixel is received
    // tilt settings take effect when the next image starts (they are actually
    // part of imaging settings, just a separate command for sensibility)
    // major and minor axis will have asymmetric memory footprint for tilt
    // gradually accumulate an average as each pixel comes in, to prevent
    // explosion of latency for any single iteration
    // don't sample major-axis tilt for the first and last rows
    // to prevent any sign ambiguity, use the ratio of voltage changes between
    // Z and X/Y
    //
    // tiltSettings mode

    NUM_MODES = 11,
  };
  
  Mode mode = Mode::idle;

  char alphaCode = 0;
  
  float attributes[10];
};
