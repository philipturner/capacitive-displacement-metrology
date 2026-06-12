#pragma once

#include <stdint.h>

struct PixelBuffer {
  static constexpr uint32_t capacity = 100;
  
  struct Pixel {
    uint32_t writeIterationID;
    uint32_t id;
    float x; // units: nm
    float y; // units: nm
    float z; // units: nm
  };
  Pixel pixels[capacity];

  PixelBuffer();

  void addPixel(Pixel pixel);
  bool hasReadyPixel() const;
  void flushReadyPixel();

private:
  uint32_t startIndex = 0;
  uint32_t endIndex = 0;
};
