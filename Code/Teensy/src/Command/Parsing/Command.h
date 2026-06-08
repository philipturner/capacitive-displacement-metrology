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

    // aN - dominant scan axis, 0 = x, 1 = y
    // cX,Y - creep constants, in multiples of 0.01%/decade
    // lN - wait ~N μs for fixed time lag of electronics
    // oI,X,Y - center #I, position (X, Y) in multiples of 0.1 nm
    // r - reset to defaults
    // sN - wait ~N ms for creep settling in dual video mode
    imagingSettings = 12,

    NUM_MODES = 13,
  };
  
  Mode mode = Mode::idle;

  char alphaCode = 0;

  // TODO: Double check all files that touch 'attributes'; it was recently
  // changed from 'int32_t' to 'float'.
  float attributes[10];
};
