#include <Arduino.h>
#include "Metrology.h"

struct Trial {
  static constexpr uint32_t intervalCount = 8;
  static constexpr float voltages[intervalCount + 1] = {
    -420, -210, 0, 210,
    420, 210, 0, -210, -420
  };
  float samples[9];
  float times[9];
};

enum class TrialType: uint32_t {
  signal = 0,
  noise = 1,
};

void Metrology::hysteresisPlot() {
  if (metrologyDesc.mode != Mode::metrology) {
    Serial.print("Can only call this function in metrology mode.");
    exit(0);
  }

  changeVoltage(0, -420);
  float startingCapacitance = cdcSingleSample();
  float startingTime = float(millis()) / 1000;

  constexpr uint32_t trialCount = 5;
  Trial signalTrials[trialCount];
  Trial noiseTrials[trialCount];

  for (uint32_t trialID = 0; trialID < trialCount * 2; ++trialID) {
    TrialType trialType = static_cast<TrialType>(trialID % 2);

    //for (uint8_)
  }

  changeVoltage(-420, 0);
}