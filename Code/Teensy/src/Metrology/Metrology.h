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

  struct Descriptor {
    Mode mode;
    float waveformBipolarVoltage = 0;
    uint8_t cdcCapdacCode = 20;
    uint32_t basicMeasurementHistorySize = 30;
  };

  // Initializer for global variable initialization.
  Metrology();

  ~Metrology();

  // Procedure to call in Arduino 'setup()'.
  Metrology(Descriptor metrologyDesc);

  void loop();

private:
  Descriptor metrologyDesc;
  float *capacitanceHistory;
  uint32_t infiniteLoopIndex = 0;

public:
  // Input: progress, 0 to 1
  // Output: interpolation, 0 to 1
  float smoothstep(float progress);

  void changeVoltage(float startVoltage, float endVoltage);

  float cdcSingleSample();

private:
  // CDC must be in continuous conversion mode.
  void basicCapacitanceMeasurementLoop();

  void waveformTestingLoop();

public:
  struct ProgramDescriptor {
    bool logSingleSamples = false;
    bool verboseDriftCancellation = true;
    float bipolarVoltage = 0;
    float creepTime = 0.0;
  };

  struct ProgramResult {
    static constexpr uint32_t trialCount = 3;
    float dx[trialCount];
    float dx_creep[trialCount];
  };

  ProgramResult metrologyProgram(ProgramDescriptor programDesc);

  // Characterize the voltage-position relation of a LiNbO3 plate or stack.
  void lithiumNiobateProgram();
};