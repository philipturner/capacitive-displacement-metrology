#pragma once

#include "Command/Parsing/Command.h"
#include "Util/Vector.h"

struct Imager {
  enum class Mode {
    image = 0,
    video = 1,
    dualVideo = 2,
  };

  struct Settings {
    uint8_t dominantAxis = 0; // either 0 or 1
    float2 centers[2] = {
      float2(), 
      float2(),
    };
    uint32_t electronicTimeLag = 0; // μs
    uint32_t creepSettlingTime = 0; // μs

    Settings() { }
  };
  static inline Settings pendingSettings;

  // 1668 - 1e-3 resonant overshoot, 2.65 kHz
  // 3324 - 1e-4 resonant overshoot, 2.65 kHz
  // 5904 - 1e-5 resonant overshoot, 2.65 kHz
  static constexpr uint32_t largeMoveRiseTime = 5904; 
  static constexpr uint32_t pixelTime = 96;
  
  Imager();
  Imager(Command command);
  void update();

  static Mode getMode(char code);
  static void updatePendingSettings(Command command);
  void forwardSettings();

private:
  Mode mode;
  uint32_t resolution;
  float imageSize; // units: nm
  float pixelDimension; // units: nm
  uint32_t polynomialPeakTime;
  Settings settings;
  
  uint32_t getRowTime() const;
  uint32_t getImageTime() const;
  float getPeakValue(float amplitudeNormalized) const;

  float2 previousImageEnd;
  float2 getPosition(float2 localPosition, uint32_t imageID);
  float2 getPosition(uint32_t timeInImage, uint32_t imageID);

  void writePixel(float2 position, uint32_t timeInImage);
};