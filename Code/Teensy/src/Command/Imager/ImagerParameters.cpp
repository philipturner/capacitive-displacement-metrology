#include "Imager.h"

#include "Diagnostics/Log.h"
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

bool validateImageBounds(float X, float Y, float S) {
  float bounds[4] = {
    X - S / 2,
    Y - S / 2,
    X + S / 2,
    Y + S / 2,
  };

  for (uint32_t i = 0; i < 4; ++i) {
    float bound = bounds[i];
    if (bound < -135 || bound > 135) {
      CommandTracker::throwError(
        "Invalid image bounds.",
        int32_t(i),
        int32_t(bound * 10));
      return false;
    }
  }

  return true;
}

bool Imager::checkAttributes(Command command) {
  uint32_t resolution = command.attributes[0];
  if (resolution == 0 || resolution > 1024) {
    CommandTracker::throwError(
      "Invalid resolution.",
      resolution);
    return false;
  }
  if (resolution % 2 != 0) {
    CommandTracker::throwError(
      "Resolution must be even.",
      resolution);
    return false;
  }

  float size = float(command.attributes[1]) * 0.1;
  if (size <= 0 || size > 270) {
    CommandTracker::throwError(
      "Invalid size.",
      int32_t(size * 10));
    return false;
  }

  float X = float(command.attributes[2]) * 0.1;
  float Y = float(command.attributes[3]) * 0.1;
  if (!validateImageBounds(X, Y, size)) {
    return false;
  }

  if (command.alphaCode == 'd') {
    float X2 = float(command.attributes[4]) * 0.1;
    float Y2 = float(command.attributes[5]) * 0.1;
    if (!validateImageBounds(X2, Y2, size)) {
      return false;
    }
  }

  return true;
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
    centersY[1]);
}