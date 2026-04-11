#include <Arduino.h>
#include "Metrology.h"

struct Trial {
  static constexpr uint32_t intervalCount = 8;
  static constexpr float voltages[intervalCount + 1] = {
    -420, -210, 0, 210,
    420, 210, 0, -210, -420
  };
  float displacements[intervalCount + 1];
  float times[intervalCount + 1];
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
  float dCdx = Metrology::calculate_dCdx(startingCapacitance);
  float startingTime = float(millis()) / 1000;

  constexpr uint32_t trialCount = 5;
  Trial signalTrials[trialCount];
  Trial noiseTrials[trialCount];

  for (uint32_t trialID = 0; trialID < trialCount; ++trialID) {
    Serial.print("trial ");
    Serial.print(trialID);
    Serial.println();
    
    for (uint32_t i = 0; i < 2; ++i) {
      TrialType trialType = static_cast<TrialType>(i);
      Trial trial;

      for (uint32_t intervalID = 0; intervalID <= Trial::intervalCount; ++intervalID) {
        float capacitance = cdcSingleSample();
        float time = float(millis()) / 1000;

        float dC = capacitance - startingCapacitance;
        float dx = dC / dCdx;
        float dt = time - startingTime;

        trial.displacements[intervalID] = dx;
        trial.times[intervalID] = dt;

        if (intervalID == Trial::intervalCount) {
          break;
        }

        if (trialType == TrialType::signal) {
          changeVoltage(
            Trial::voltages[intervalID], 
            Trial::voltages[intervalID + 1]);
        } else {
          changeVoltage(-420, -420);
        }
      }

      if (trialType == TrialType::signal) {
        signalTrials[trialID] = trial;
      } else {
        noiseTrials[trialID] = trial;
      }
    }
  }

  changeVoltage(-420, 0);

  for (uint32_t i = 0; i < 2; ++i) {
    TrialType trialType = static_cast<TrialType>(i);
    Serial.println();

    for (uint32_t trialID = 0; trialID < trialCount; ++trialID) {
      Trial trial;
      if (trialType == TrialType::signal) {
        trial = signalTrials[trialID];
      } else {
        trial = noiseTrials[trialID];
      }
      
      for (uint32_t intervalID = 0; intervalID <= Trial::intervalCount; ++intervalID) {
        float voltage = Trial::voltages[intervalID];
        Serial.print(voltage, 1);
        Serial.print(", ");
        
        float displacement = trial.displacements[intervalID];
        Serial.print(displacement, 1);
        Serial.print(", ");

        float time = trial.times[intervalID];
        Serial.print(time, 3);
        Serial.println();
      }
    }
  }
}
