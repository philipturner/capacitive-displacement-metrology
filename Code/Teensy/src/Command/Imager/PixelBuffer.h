#pragma once

#include <stdint.h>

// Create data type to encapsulate:
// Fixed-size buffer (100 entries) for pixels
// Tracking the start and end cursor of the ring buffer

struct PixelBuffer {
  struct Pixel {
    uint32_t writeIterationID;
    uint32_t id;
    float x; // units: nm
    float y; // units: nm
    float z; // units: nm
    float current; // units: A
  };
  Pixel *pixels;

  PixelBuffer();
  PixelBuffer(uint32_t capacity);

  ~PixelBuffer();
};
