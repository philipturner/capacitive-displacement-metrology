#include "Imager.h"

#include "Application/Application.h"
#include "Util/Feedback.h"
#include "Util/FilterUtil.h"
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

Imager::Imager() {

}

Imager::Imager(Command command) {
  mode = getMode(command.alphaCode);
  resolution = uint32_t(command.attributes[0]);
  imageSize = float(command.attributes[1]) * 0.1;

  centersX[0] = float(command.attributes[2]) * 0.1;
  centersY[0] = float(command.attributes[3]) * 0.1;

  if (mode == Mode::dualVideo) {
    centersX[1] = float(command.attributes[4]) * 0.1;
    centersY[1] = float(command.attributes[5]) * 0.1;
  } else {
    centersX[1] = -100;
    centersY[1] = -100;
  }
}

uint32_t Imager::getRowTime() const {
  return polynomialPeakTime + resolution * pixelTime;
}

uint32_t Imager::getImageTime() const {
  uint32_t output = 0;
  output += largeMoveRiseTime;
  output += resolution * getRowTime();
  output += polynomialPeakTime;
  return output;
}

void Imager::update() {
  uint32_t time = Application::state.getTimeSinceModeStart();
  if (time == 0) {
    Application::updateBiasVoltage(Feedback::setpointVoltage);
  }
  Feedback::updatePiezoZ();

  uint32_t imageTime = getImageTime();
  uint32_t imageID = time / imageTime;
  uint32_t timeInImage = time % imageTime;

  if (timeInImage == 0) {
    previousX = Application::state.piezoXVoltage * 0.320;
    previousY = Application::state.piezoYVoltage * 0.320;

    if (mode == Mode::dualVideo && (imageID % 2 == 1)) {
      imageCenterX = centersX[1];
      imageCenterY = centersY[1];
    } else {
      imageCenterX = centersX[0];
      imageCenterY = centersY[0];
    }
  }

  if (mode == Mode::image && imageID > 0) {
    return;
  }

  float x = 0;
  float y = 0;
  getPosition(x, y, timeInImage, imageID);
  Application::updatePiezoVoltage(1, x / 0.320);
  Application::updatePiezoVoltage(2, y / 0.320);
}

void Imager::getPosition(
  float &x, 
  float &y, 
  uint32_t timeInImage, 
  uint32_t imageID
) {
  float linearPartVelocity = imageSize / float(resolution * pixelTime);
  float peakDefaultVelocity = 1 / float(polynomialPeakTime);
  float peakScaleFactor = linearPartVelocity / peakDefaultVelocity;

  if (timeInImage < largeMoveRiseTime) {
    float peakValue = FilterUtil::polynomialWaveOutskirt(0);
    float targetPositionX = peakScaleFactor * (peakValue - 0.5);
    float targetPositionY = 0.5 * imageSize / float(resolution);
    correctNormalizedPosition(targetPositionX, targetPositionY);

    float progress = float(timeInImage) / float(largeMoveRiseTime);
    progress = FilterUtil::thirdOrderSmoothstep(progress);
  }
}

void Imager::correctNormalizedPosition(float &x, float &y) {
  x -= imageSize / 2;
  y -= imageSize / 2;

  x += imageCenterX;
  y += imageCenterY;
}