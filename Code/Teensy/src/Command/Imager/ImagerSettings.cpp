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
      pendingSettings.dominantAxis = axisCode;
      break;
    }
    case 'l': {
      uint32_t time = command.attributes[0];
      time += KilohertzLoop::period - 1;
      time -= time % KilohertzLoop::period;

      uint32_t maxTime = (PixelBuffer::capacity - 1) * Imager::pixelTime;
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
      time += KilohertzLoop::period - 1;
      time -= time % KilohertzLoop::period;

      pendingSettings.creepSettlingTime = time;
      break;
    }
  }
}

void Imager::forwardSettings() {
  Log::writeValuesWithFlags(
    /*flags=*/5,
    uint8_t(mode),
    resolutionMajor,
    resolutionMinor,
    pixelDimension,
    polynomialPeakTime);

  Log::writeValuesWithFlags(
    /*flags=*/5,
    settings.dominantAxis,
    settings.centers[0].x,
    settings.centers[0].y,
    settings.centers[1].x,
    settings.centers[1].y);

  Log::writeValuesWithFlags(
    /*flags=*/5,
    settings.electronicTimeLag,
    settings.creepSettlingTime,
    Feedback::setpointCurrent);
}
