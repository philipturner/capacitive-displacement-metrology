#pragma once

#include "Command/Parsing/Command.h"
#include "Util/Vector/Vector.h"

struct ModeChanger {
  uint32_t startIteration = 0;
  uint32_t endIteration = 0;
  
  void start(Command command);
  void update(bool &useADC) const;
  void end() const;

  static void forceModeChange();

private:
  Command command;
  bool continueFeedback = false;
  bool retractZ = false;
  float2 previousScannerVoltage;
  float2 targetScannerVoltage;
};