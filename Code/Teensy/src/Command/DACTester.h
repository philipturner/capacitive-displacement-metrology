#pragma once

#include "Command/Command.h"

struct DACTester {
  static constexpr uint32_t wavePeriod = 1008;

  DACTester();
  DACTester(Command command);

  void update();

  void writeToLog();

public:
  uint32_t channelID;

private:
  float bipolarAmplitude;
};