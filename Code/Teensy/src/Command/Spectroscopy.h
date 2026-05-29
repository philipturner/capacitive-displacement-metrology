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
  };

  // voltageSlewPeriod = 120 μs, integratePeriod = 504 μs
  // noise is average of everything, across 10 instances of integratePeriod
  //
  // positionSettlePeriod = 252 μs
  //    2 V ->  0.66 pA
  //   -2 V -> -0.76 pA
  // including pole of 10 kHz LPF:
  //    2 V ->  0.89 pA
  //   -2 V -> -1.01 pA
  //
  // positionSettlePeriod = 504 μs
  //    2 V ->  0.26 pA
  //   -2 V -> -0.38 pA
  //   1 nm ->  0.11 pA
  //  -1 nm -> -0.12 pA
  //   noise:  -0.19 pA
  //            0.77 pA (w/o 10-trial average)
  // including pole of 10 kHz LPF:
  //    2 V ->  0.25 pA
  //   -2 V -> -0.53 pA
  //   noise:  -0.24 pA
  //            0.65 pA (w/o 10-trial average)
  static constexpr uint32_t voltageSlewPeriod = 120;
  static constexpr uint32_t positionSettlePeriod = 2496;
  static constexpr uint32_t integratePeriod = 1008;
  static constexpr uint32_t feedbackTime = 30000;
  static constexpr uint32_t trialsPerResult = 10;

  static constexpr uint32_t numAutoVZPairs = 201;
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