#include "Imager.h"

#include "Diagnostics/Log.h"
#include "Util/Feedback.h"
#include <Arduino.h>

Imager::Mode Imager::getMode(char imagingAlphaCode) {
  if (imagingAlphaCode == 'i') {
    return Imager::Mode::image;
  } else if (imagingAlphaCode == 'v') {
    return Imager::Mode::video;
  } else if (imagingAlphaCode == 'd') {
    return Imager::Mode::dualVideo;
  } else {
    Serial.println("This should never happen.");
    exit(0);
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