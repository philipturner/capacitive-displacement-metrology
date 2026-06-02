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
    float sampleCount[3] = { 0, 0, 0 };
    float signBallot[3] = { 0, 0, 0 };
  };
  
  static constexpr uint32_t voltageSlewPeriod = 120;
  static constexpr uint32_t positionSettlePeriod = 2496;
  static constexpr uint32_t integratePeriod = 1008;
  static constexpr uint32_t feedbackTime = 30000;
  static constexpr uint32_t trialsPerResult = 10;

  static constexpr bool autoTypeIsPosition = true;
  static constexpr uint32_t numAutoVZPairs = 121;
  static inline VZPair autoVZPairs[numAutoVZPairs];
  static void fillAutoVZPairs();

  Spectroscopy();
  Spectroscopy(Command command);

  void update();

private:
  bool useCustomVZPair;
  VZPair customVZPair;
  float autoScaleFactor = 0;
  
  // Don't forget to reset these each trial.
  uint32_t trialStartIterationID;
  uint32_t trialID = 0;
  uint32_t pairID = 0;
  Result pendingResult1 = Result();
  Result pendingResult2 = Result();
  float restPiezoZVoltage = -270;

  uint32_t getTimeSinceTrialStart();
  uint32_t getTimePerTrial();
  uint32_t getPairCount();
  VZPair getCurrentVZPair();

  void pushResult(uint32_t sampleCount, Result& result);
  void updateState();

  void accumulate(uint32_t index);
  float getBiasVoltage(float progress);
  float getPiezoZVoltage(float progress);
};