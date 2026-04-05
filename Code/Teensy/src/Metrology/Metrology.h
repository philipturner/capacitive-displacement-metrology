#include <stdint.h>

namespace Metrology {
  enum class Mode {
    basicMeasurement = 0,
    waveformTesting = 1,
    metrology = 2,
  };

  struct Settings {
    bool logSingleSamples = true;
    bool verboseDriftCancellation = true;
    float bipolarDriveVoltage = 3;
    uint8_t cdcCapdacCode = 35;
  };
};