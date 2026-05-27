#pragma once

#include "Command/Command.h"

struct Spectroscopy {
  struct VZPair {
    // Bias voltage, in volts.
    float voltage;

    // Temporary change in position, in meters.
    float position;
  };

  struct Result {
    float accumulators[3] = { 0, 0, 0 };
  };

  static constexpr uint32_t voltageSlewPeriod = 252;
  static constexpr uint32_t positionSettlePeriod = 504;
  static constexpr uint32_t integratePeriod = 504;

  static constexpr uint32_t feedbackTime = 10080;
  static constexpr uint32_t trialsPerResult = 10;

  static constexpr uint32_t numAutoVZPairs = 1;
  static inline VZPair autoVZPairs[numAutoVZPairs];
  static void fillAutoVZPairs();

  Spectroscopy();
  Spectroscopy(Command command);

  void update();

private:
  bool useCustomVZPair;
  VZPair customVZPair;
  
  // Don't forget to reset these each trial.
  uint32_t trialStartIterationID;
  uint32_t trialID = 0;
  int32_t resultID = 0;
  Result pendingResult = Result();

  float restPiezoZVoltage;

  uint32_t getTimeSinceTrialStart();
  uint32_t getTimePerTrial();
  uint32_t getResultCount();
  VZPair getCurrentVZPair();

  void updateState();

  void accumulate(uint32_t index);
  float getBiasVoltage(float progress);
  float getPiezoZVoltage(float progress);
};