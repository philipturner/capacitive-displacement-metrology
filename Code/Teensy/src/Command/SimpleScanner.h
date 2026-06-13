#pragma once

#include "Command/Parsing/Command.h"
#include "Time/KilohertzLoop.h"

struct SimpleScanner {
  static constexpr bool usePolynomialWave = true;
  static constexpr uint32_t polynomialPeakTime = KilohertzLoopRound(1000);

  SimpleScanner();
  SimpleScanner(Command command);

  void update();

  // Returns the position of the active channel.
  float getPosition(uint32_t time) const;

private:
  uint32_t channelID;
  uint32_t halfWavePeriod;
  float peakPeakAmplitude;
};