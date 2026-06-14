#include "PixelBuffer.h"

#include "Application/Application.h"
#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
#include <Arduino.h>

PixelBuffer::PixelBuffer() {

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

  Log::writeValuesWithFlags(
    /*flags=*/4,
    pixel.id,
    pixel.x,
    pixel.y,
    pixel.z,
    abs(Application::state.filteredCurrent * 1e12));
}