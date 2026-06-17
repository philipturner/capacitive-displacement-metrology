#pragma once

#include "Command/Parsing/Command.h"
#include "Time/KilohertzLoop.h"

struct DACTester {
  static constexpr uint32_t wavePeriod = KilohertzLoopRound(1000);

  DACTester();
  DACTester(Command command);

  void update();

  float getActiveChannelVoltage();

public:
  uint32_t channelID;

private:
  float bipolarAmplitude;
};