#pragma once

#include "Command/Imager/PixelBuffer.h"
#include "Command/Parsing/Command.h"
#include "Time/KilohertzLoop.h"
#include "Util/Vector/Vector.h"

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
  static constexpr uint32_t largeMoveRiseTime = KilohertzLoopRound(5900); 
  static constexpr uint32_t pixelTime = KilohertzLoopRound(100);
  
  Imager();
  Imager(Command command);
  void adjustScanFrequency();
  void update();

  static Mode getMode(char code);
  static void updatePendingSettings(Command command);
  void forwardSettings() const;

  static uint32_t getMidPixelTime();
  static float getCurrentStateWeight();

  // Transform Z and I before transmitting over serial.
  static float transformVoltageZ(float original);
  static float transformCurrent(float original);

  // The XY voltage before creep correction.
  float2 getUncorrectedVoltageXY() const;

private:
  Mode mode;
  uint32_t resolutionMajor;
  uint32_t resolutionMinor;
  float pixelDimension; // units: nm
  uint32_t polynomialPeakTime;
  Settings settings;
  PixelBuffer pixelBuffer;
  
  uint32_t getRowTime() const;
  uint32_t getImageTime() const;
  float getPeakValue(float amplitudeNormalized) const;

  float2 previousImageEnd;
  float2 previousVoltageXY = float2(0);
  float2 currentVoltageXY = float2(0);
  float2 getPosition(float2 localPosition, uint32_t imageID);
  float2 getPosition(uint32_t timeInImage, uint32_t imageID);

  int32_t getPixelID(uint32_t timeInImage);
  void addPixel(uint32_t pixelID);
};