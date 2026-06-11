#include "Imager.h"

#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
#include "Util/Feedback.h"
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
  Serial.println();
  Serial.println("Forwarding settings:");

  Log::writeValuesWithFlags(
    /*flags=*/4,
    uint8_t(mode),
    resolution,
    imageSize,
    polynomialPeakTime,
    Feedback::setpointCurrent);

  Serial.println();
  Serial.println(uint8_t(mode));
  Serial.println(resolution);
  Serial.println(imageSize);
  Serial.println(polynomialPeakTime);
  Serial.println(Feedback::setpointCurrent);
  
  Log::writeValuesWithFlags(
    /*flags=*/4,
    settings.dominantAxis,
    settings.centers[0].x,
    settings.centers[0].y,
    settings.centers[1].x,
    settings.centers[1].y);
  
  Serial.println();
  Serial.println(settings.dominantAxis);
  Serial.println(settings.centers[0].x);
  Serial.println(settings.centers[0].y);
  Serial.println(settings.centers[1].x);
  Serial.println(settings.centers[1].y);
  
  Log::writeValuesWithFlags(
    /*flags=*/4,
    settings.electronicTimeLag,
    settings.creepSettlingTime);
  
  Serial.println();
  Serial.println(settings.electronicTimeLag);
  Serial.println(settings.creepSettlingTime);
  Serial.println();
}
