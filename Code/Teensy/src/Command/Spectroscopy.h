#pragma once

#include "Command/Parsing/Command.h"
#include "Time/KilohertzLoop.h"

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
  
  static constexpr uint32_t voltageSlewPeriod = KilohertzLoopRound(120);
  static constexpr uint32_t positionSettlePeriod = KilohertzLoopRound(150); // 2500
  static constexpr uint32_t integratePeriod = KilohertzLoopRound(1000);
  static constexpr uint32_t delayBeforeFeedback = KilohertzLoopRound(15000);
  static constexpr uint32_t feedbackTime = KilohertzLoopRound(30000);
  static constexpr uint32_t trialsPerResult = 10;

  static constexpr bool autoTypeIsPosition = false;
  static constexpr uint32_t numAutoVZPairs = 1;
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

  void pushResult(uint32_t sampleCount, Result& result);
  void updateState();
  bool shouldUpdateForTrial();
  void updateForTrial();

  uint32_t getTimeSinceTrialStart();
  uint32_t getTimePerTrial();
  uint32_t getPairCount();
  VZPair getCurrentVZPair();

  void accumulate(uint32_t index);
  float getBiasVoltage(float progress);
  float getPiezoZVoltage(float progress);
};