#include "PixelBuffer.h"

#include <Arduino.h>

PixelBuffer::PixelBuffer() {
  pixels = nullptr;
}

PixelBuffer::PixelBuffer(uint32_t capacity) {
  pixels = new Pixel[capacity];
  if (pixels == nullptr) {
    Serial.println("Could not allocate memory.");
    exit(0);
  }
}

PixelBuffer::~PixelBuffer() {
  if (pixels != nullptr) {
    delete[] pixels;
  }
}