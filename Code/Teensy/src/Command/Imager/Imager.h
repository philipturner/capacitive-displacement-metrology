#pragma once

#include "Command/Imager/PixelBuffer.h"
#include "Command/Parsing/Command.h"
#include "Time/KilohertzLoop.h"
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
  static constexpr uint32_t largeMoveRiseTime = KilohertzLoopRound(5900); 
  static constexpr uint32_t pixelTime = KilohertzLoopRound(96);

  // TODO: 
  // - Clone the previous state and interpolate pixels halfway in time
  // - Make electronic time lag no longer restricted to multiples of loop period
  // - Make it so that evenly divisible pixel times have a weight of 0 for the
  //   contribution from the past pixel
  // - This impact both XYZ when registering the pixel and current when actually
  //   writing the pixel after a time lag.
  //
  // Writing stuff into the tilt tracker is decoupled from the time lag for
  // DACs -> current response, because tilt just tracks a relation between X/Y/Z
  // and Z feedback is way too slow to be characterized by electronic time lag.
  
  Imager();
  Imager(Command command);
  void adjustScanFrequency();
  void update();

  static Mode getMode(char code);
  static void updatePendingSettings(Command command);
  void forwardSettings() const;

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
  float2 getPosition(float2 localPosition, uint32_t imageID);
  float2 getPosition(uint32_t timeInImage, uint32_t imageID);

  void createPendingPixel(float2 position, uint32_t timeInImage);
};