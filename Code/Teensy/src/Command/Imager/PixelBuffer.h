#pragma once

#include <stdint.h>

struct PixelBuffer {
  static constexpr uint32_t capacity = 100;
  
  struct Pixel {
    uint32_t writeIterationID;
    uint32_t id;
    float voltageX; // units: nm
    float voltageY; // units: nm
    float voltageZ; // units: nm
  };
  Pixel pixels[capacity];

  PixelBuffer();

  void updateCurrent();
  void addPixel(Pixel pixel);
  bool hasReadyPixel() const;
  void flushReadyPixel(uint32_t timeLag);

  // TODO: Move to private properties.
  float laggedCurrent = 0;
  float latestCurrent = 0;

private:
  uint32_t startIndex = 0;
  uint32_t endIndex = 0;
  
};
