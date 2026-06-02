#pragma once

#include "Command/Command.h"

struct SimpleScanner {
  static constexpr bool usePolynomialWave = false;
  static constexpr uint32_t polynomialPeakTime = 1008;

  SimpleScanner();
  SimpleScanner(Command command);

private:
  uint32_t channelID;
  uint32_t halfWavePeriod;
  float peakPeakAmplitude;
};