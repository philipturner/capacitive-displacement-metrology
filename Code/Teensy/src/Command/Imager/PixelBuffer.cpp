#include "PixelBuffer.h"

#include "Application/Application.h"
#include "Command/Imager/Imager.h"
#include "Command/Tilt/Settings.h"
#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
#include "Util/Interpolate.h"
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

  float relativeZVoltage = Tilt::Settings::getRelativeZ(
    pixel.voltageX,
    pixel.voltageY,
    pixel.voltageZ);

  float oldCurrent = Application::state.previous.w;
  float newCurrent = Application::state.filteredCurrent;
  float progress = Imager::getCurrentStateWeight();
  float current = interpolate(oldCurrent, newCurrent, progress);
  
  if (!ErrorMessage::hasError()) {
    Log::writeValuesWithFlags(
      4, // flags
      Log::encodeRawBits(pixel.id),
      pixel.voltageX * 0.320f,
      pixel.voltageY * 0.320f,
      Imager::transformVoltageZ(relativeZVoltage) * 0.320f,
      Imager::transformCurrent(current));
  }
}