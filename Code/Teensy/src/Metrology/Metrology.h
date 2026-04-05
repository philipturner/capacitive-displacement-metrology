#pragma once

#include <stdint.h>

class Metrology {
public:
  enum class Mode {
    invalid = 0,
    basicMeasurement = 1,
    waveformTesting = 2,
    metrology = 3,
  };

  struct Settings {
    Mode mode;
    bool logSingleSamples = true;
    bool verboseDriftCancellation = true;
    float bipolarDriveVoltage = 3;
    uint8_t cdcCapdacCode = 35;
    uint32_t samplesPerAverage = 30;
  };

  // Initializer for global variable initialization.
  Metrology();

  // Procedure to call in Arduino 'setup()'.
  Metrology(Settings settings);

  ~Metrology();
  
  void loop();

private:
  Settings settings;
  float *capacitanceHistory;
  uint32_t infiniteLoopIndex = 0;

public:
  // Input: progress, 0 to 1
  // Output: interpolation, 0 to 1
  float smoothstep(float progress);

  void changeVoltage(float startVoltage, float endVoltage);

  float cdcSingleSample();

public:
  // CDC must be in continuous conversion mode.
  void basicCapacitanceMeasurementLoop();

  void waveformTestingLoop();

  void metrologyProgram();
};