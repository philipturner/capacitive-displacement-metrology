#include "PixelBuffer.h"

#include "Application/Application.h"
#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
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

  this->capacity = capacity;
  startIndex = 0;
  endIndex = 0;
}

PixelBuffer::~PixelBuffer() {
  if (pixels != nullptr) {
    delete[] pixels;
  }
}

void PixelBuffer::addPixel(Pixel pixel) {
  if (startIndex > endIndex) {
    Serial.println("Unexpected behavior regarding indices.");
    exit(0);
  }

  uint32_t filledSlots = endIndex - startIndex;
  if (filledSlots >= capacity) {
    Serial.println("Pixel buffer ran out of capacity.");
    exit(0);
  }

  pixels[endIndex % capacity] = pixel;
  endIndex += 1;
}

bool PixelBuffer::hasReadyPixel() const {
  uint32_t filledSlots = endIndex - startIndex;
  if (filledSlots == 0) {
    return false;
  }

  Pixel pixel = pixels[startIndex % capacity];

  if (KilohertzLoop::iterationID >= pixel.writeIterationID) {
    return true;
  } else {
    return false;
  }
}

void PixelBuffer::flushReadyPixel() {
  Pixel pixel = pixels[startIndex % capacity];
  startIndex += 1;

  Serial.print("Flushing pixel #");
  Serial.print(pixel.id);
  Serial.print(", current iteration ");
  Serial.print(KilohertzLoop::iterationID);
  Serial.println();

  #if 0
  Log::writeValuesWithFlags(
    /*flags=*/5,
    pixel.id,
    pixel.x,
    pixel.y,
    pixel.z,
    Application::state.filteredCurrent);
  #endif
}