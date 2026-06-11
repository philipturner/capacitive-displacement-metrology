#pragma once

#include <stdint.h>

struct PixelBuffer {
  struct Pixel {
    uint32_t writeIterationID;
    uint32_t id;
    float x; // units: nm
    float y; // units: nm
    float z; // units: nm
  };
  Pixel *pixels;

  PixelBuffer();
  PixelBuffer(uint32_t capacity);
  ~PixelBuffer();

  void addPixel(Pixel pixel);
  bool hasReadyPixel() const;
  void flushReadyPixel();

private:
  uint32_t capacity;
  uint32_t startIndex;
  uint32_t endIndex;
};
