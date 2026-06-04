#pragma once

#include "Command/Command.h"

struct Imager {
  enum class Mode {
    image = 0,
    video = 1,
    dualVideo = 2,
  };

  struct Pixel {
    uint32_t id;
    float x; // units: nm
    float y; // units: nm
    float z; // units: nm
    float current; // units: A
  };

  static constexpr uint32_t largeMoveRiseTime = 5004;
  static constexpr uint32_t polynomialPeakTime = 1008;
  static constexpr uint32_t pixelTime = 96;
  static constexpr uint32_t currentTimeLagRoundedUp = 72;
  static constexpr float currentTimeLagHighRes = 63.6;

  Imager();
  Imager(Command command);
  void update();

  static Mode getMode(char code);
  static bool checkAttributes(Command command);
  void forwardParameters();

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
  void correctNormalizedPosition(float &x, float &y);

  float previousCurrent = 0;
  uint32_t writePixelIterationID = UINT32_MAX;
  Pixel pendingPixel;
  void updatePendingPixel(uint32_t timeInImage);
};