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
    // ~1 kHz triangle wave, +/-AAA volts
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

    // TODO: Change to generate rectangular images
    // major axis, minor axis, size of major axis
    //
    // - This is important to maximally reject thermal drift interference while
    //   getting high spatial resolution along one axis.
    // - Scanned major and stored major resolutions are different, and must be
    //   transmitted to the PC: thus, 3 pixel resolutions in total.
    // - When major and minor resolutions differ, there are complications with
    //   the Fourier transform. Handle these gracefully and resample the 
    //   Fourier image to avoid distortions.
    //
    // iM,N,S - single image
    // vM,N,S - repeating video at single spot
    // dM,N,S - dual video, alternating between two spots
    //
    // M (major) x N (minor) image, S nm along major axis
    imaging = 8,

    // aN - major axis index
    // fN - set feedback time constant to N ms while scanning
    // lN - wait N μs for fixed time lag of electronics
    // oI,X,Y - center #I, position (X, Y) in nm
    // r - reset to defaults
    // sN - wait N ms for creep settling
    imagingSettings = 9,

    // cN - set creep constant for both axes
    // xN - set creep constant for X only
    // yN - set creep constant for Y only
    creepSettings = 10,

    // cD,T - calculate with D nm, T ms per displacement
    // oD,T,X,Y - calculate with origin specified
    tiltCalculation = 11,

    // tX,Y - set slope for each axis
    tiltSettings = 12,

    NUM_MODES = 13,
  };

  bool isValid = true;
  
  Mode mode = Mode::idle;

  char alphaCode = 0;
  
  float attributes[10];
};
