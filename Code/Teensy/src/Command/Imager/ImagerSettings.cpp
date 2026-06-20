#include "Imager.h"

#include "Diagnostics/Log.h"
#include "Filter/Feedback.h"
#include "Time/KilohertzLoop.h"
#include <Arduino.h>

Imager::Mode Imager::getMode(char code) {
  if (code == 'i') {
    return Imager::Mode::image;
  } else if (code == 'v') {
    return Imager::Mode::video;
  } else if (code == 'd') {
    return Imager::Mode::dualVideo;
  } else {
    Serial.println("This should never happen.");
    exit(0);
  }
}

void Imager::updatePendingSettings(Command command) {
  switch (command.alphaCode) {
    case 'a': {
      uint8_t axisCode = command.attributes[0];
      pendingSettings.majorAxis = axisCode;
      break;
    }
    case 'f': {
      float timeConstantMillis = command.attributes[0];
      uint32_t timeConstantMicros = ceil(timeConstantMillis * 1000);
      pendingSettings.feedbackTimeConstant = timeConstantMicros;
      break;
    }
    case 'l': {
      uint32_t time = rint(command.attributes[0]);
      uint32_t maxTime = (PixelBuffer::capacity - 2) * Imager::pixelTime;
      time = min(time, maxTime);

      pendingSettings.electronicTimeLag = time;
      break;
    }
    case 'o': {
      uint8_t centerID = command.attributes[0];
      float x = command.attributes[1];
      float y = command.attributes[2];
      pendingSettings.centers[centerID] = float2(x, y);
      break;
    }
    case 'r': {
      pendingSettings = Settings();
      break;
    }
    case 's': {
      uint32_t time = command.attributes[0] * 1000;
      time = KilohertzLoopRound(time);
      
      pendingSettings.creepSettlingTime = time;
      break;
    }
  }
}

void Imager::forwardSettings() const {
  Log::write(
    Log::Flags::imagingSettings,
    uint8_t(mode),
    _trueResolutionMajor,
    _resolutionMajor,
    _resolutionMinor,
    pixelDimension);

  Log::write(
    Log::Flags::imagingSettings,
    settings.majorAxis,
    settings.centers[0].x,
    settings.centers[0].y,
    settings.centers[1].x,
    settings.centers[1].y);

  Log::write(
    Log::Flags::imagingSettings,
    polynomialPeakTime,
    settings.electronicTimeLag,
    float(settings.creepSettlingTime) / 1000.0f,
    float(getImageTime()) / 1000.0f,
    float(settings.feedbackTimeConstant) / 1000.0f);
  
  Log::write(
    Log::Flags::imagingSettings,
    Feedback::setpointCurrent * 1e12f);
}
