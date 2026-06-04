#pragma once

#include "Command/Command.h"

struct SimpleScanner {
  static constexpr bool usePolynomialWave = true;
  static constexpr uint32_t polynomialPeakTime = 1008;

  SimpleScanner();
  SimpleScanner(Command command);

  static bool checkAttributes(Command command);

  void update();

private:
  uint32_t channelID;
  uint32_t halfWavePeriod;
  float peakPeakAmplitude;
};