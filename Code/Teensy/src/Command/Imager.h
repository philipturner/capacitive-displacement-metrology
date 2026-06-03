#pragma once

#include "Command/Command.h"

struct Imager {
  enum class Mode {
    image = 0,
    video = 1,
    dualVideo = 2,
  };

  static constexpr uint32_t largeMoveRiseTime = 5004;
  static constexpr uint32_t polynomialPeakTime = 1008;
  static constexpr uint32_t pixelTime = 96;
  static constexpr uint32_t currentTimeLag = 72;

  Imager();
  Imager(Command command);

  static Mode getMode(char code);

  void update();

  Mode mode;

private:
  // TODO
};