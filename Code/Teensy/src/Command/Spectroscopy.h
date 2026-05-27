#pragma once

#include "Command/Command.h"

struct Spectroscopy {
  struct VZPair {
    // Bias voltage, in volts.
    float voltage;

    // Temporary change in position, in meters.
    float position;
  };

  Spectroscopy();
  Spectroscopy(Command command);

  void update();

  static constexpr uint32_t numAutoVZPairs = 1;
  static inline VZPair autoVZPairs[numAutoVZPairs];
  static void fillAutoVZPairs();

private:
  bool useCustomVZPair;
  VZPair customVZPair;
};