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
  static constexpr uint32_t currentTimeLag = 0; // 72

  Imager();
  Imager(Command command);

  static Mode getMode(char code);

  void update();

  Mode mode;

private:
  uint32_t resolution;
  float imageSize; // units: nm
  float centersX[2]; // units: nm
  float centersY[2]; // units: nm

  uint32_t getRowTime() const;
  uint32_t getImageTime() const;

  float previousX = 0;
  float previousY = 0;
  float imageCenterX = 0;
  float imageCenterY = 0;
  void getPosition(
    float &x, 
    float &y, 
    uint32_t timeInImage, 
    uint32_t imageID);
  void correctNormalizedPosition(
    float &x,
    float &y);
};