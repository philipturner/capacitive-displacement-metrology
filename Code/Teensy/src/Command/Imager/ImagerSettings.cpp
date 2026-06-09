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
    case 'c': {
      float constantX = command.attributes[0] * 0.01;
      float constantY = command.attributes[1] * 0.01;
      pendingSettings.creepConstants[0] = constantX;
      pendingSettings.creepConstants[1] = constantY;
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
      float centerX = command.attributes[1];
      float centerY = command.attributes[2];
      pendingSettings.centers[centerID][0] = centerX;
      pendingSettings.centers[centerID][1] = centerY;
      break;
    }
    case 'r': {
      pendingSettings = Settings();
      break;
    }
    case 's': {
      uint32_t time = command.attributes[0];
      pendingSettings.creepSettlingTime = time;
      break;
    }
  }
}

void Imager::forwardParameters() {
  Log::writeValuesWithFlags(
    /*flags=*/4,
    float(mode),
    float(resolution),
    imageSize,
    centersX[0],
    centersY[0]);
  
  Log::writeValuesWithFlags(
    /*flags=*/4,
    centersX[1],
    centersY[1],
    Feedback::setpointCurrent);
}