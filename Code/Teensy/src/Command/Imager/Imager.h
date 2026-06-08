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

  // 1668 - 1e-3 resonant overshoot, 2.65 kHz
  // 3324 - 1e-4 resonant overshoot, 2.65 kHz
  // 5904 - 1e-5 resonant overshoot, 2.65 kHz
  static constexpr uint32_t largeMoveRiseTime = 5904; 
  static constexpr uint32_t pixelTime = 96;

  Imager();
  Imager(Command command);
  void update();

  static Mode getMode(char code);
  static bool checkAttributes(Command command);
  void forwardParameters();

  Mode mode;

private:
  uint32_t resolution;
  uint32_t polynomialPeakTime;
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