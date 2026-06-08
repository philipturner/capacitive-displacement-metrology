#include "Imager.h"

#include "Application/Application.h"
#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
#include "Util/Feedback.h"
#include "Util/FilterUtil.h"
#include <Arduino.h>

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

  if (resolution <= 32) {
    polynomialPeakTime = 1008;
  } else if (resolution <= 48) {
    polynomialPeakTime = 1500;
  } else {
    polynomialPeakTime = 2004;
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
  Feedback::updatePiezoZ(false);

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

  updatePendingPixel(timeInImage);

  if (KilohertzLoop::iterationID == writePixelIterationID) {
    Log::writeValuesWithFlags(
      /*flags=*/5,
      float(pendingPixel.id),
      pendingPixel.x,
      pendingPixel.y,
      pendingPixel.z,
      Application::state.filteredCurrent);
  }
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

  uint32_t time = timeInImage;
  if (time < largeMoveRiseTime) {
    float peakValue = FilterUtil::polynomialWaveOutskirt(0);
    float targetPositionX = peakScaleFactor * (peakValue - 0.5);
    float targetPositionY = 0.5 * imageSize / float(resolution);
    correctNormalizedPosition(targetPositionX, targetPositionY);

    float progress = float(time) / float(largeMoveRiseTime);
    progress = FilterUtil::thirdOrderSmoothstep(progress);
    x = previousX * (1 - progress) + targetPositionX * progress;
    y = previousY * (1 - progress) + targetPositionY * progress;
    return;
  } else {
    time -= largeMoveRiseTime;
  }

  if (time < resolution * getRowTime()) {
    uint32_t rowID = time / getRowTime();
    time = time % getRowTime();

    if (time < polynomialPeakTime) {
      float progress = float(time) / float(polynomialPeakTime);
      float peakValue;
      if (rowID == 0) {
        peakValue = FilterUtil::polynomialWaveOutskirt(progress);
      } else {
        peakValue = FilterUtil::polynomialWaveBend(progress);
      }
      x = peakScaleFactor * (peakValue - 0.5);
      
      float startRowID = max(0, float(rowID) - 1);
      float endRowID = max(0, float(rowID));
      float interpolatedRowID = startRowID * (1 - progress) + endRowID * progress;
      y = (interpolatedRowID + 0.5) * imageSize / float(resolution);
    } else {
      time -= polynomialPeakTime;

      float progress = float(time) / float(resolution * pixelTime);
      x = progress * imageSize;
      y = (float(rowID) + 0.5) * imageSize / float(resolution);
    }

    if (rowID % 2 == 1) {
      x = imageSize - x;
    }
  } else {
    time -= resolution * getRowTime();
    time = min(time, polynomialPeakTime);

    float progress = float(time) / float(polynomialPeakTime);
    progress = 1 - progress;

    float peakValue = FilterUtil::polynomialWaveOutskirt(0);
    x = peakScaleFactor * (peakValue - 0.5);
    y = (float(resolution) - 0.5) * imageSize / float(resolution);
  }

  correctNormalizedPosition(x, y);
}

void Imager::correctNormalizedPosition(float &x, float &y) {
  x -= imageSize / 2;
  y -= imageSize / 2;

  x += imageCenterX;
  y += imageCenterY;
}

void Imager::updatePendingPixel(uint32_t timeInImage) {
  uint32_t time = timeInImage;
  if (time < largeMoveRiseTime) {
    return;
  } else {
    time -= largeMoveRiseTime;
  }

  if (time >= resolution * getRowTime()) {
    return;
  }

  uint32_t rowID = time / getRowTime();
  time = time % getRowTime();

  if (time < polynomialPeakTime) {
    return;
  } else {
    time -= polynomialPeakTime;
  }

  uint32_t columnID = time / pixelTime;
  time = time % pixelTime;
  if (time != pixelTime / 2) {
    return;
  }

  if (rowID % 2 == 1) {
    columnID = (resolution - 1) - columnID;
  }

  writePixelIterationID = KilohertzLoop::iterationID;
  writePixelIterationID += currentTimeLagRoundedUp / KilohertzLoop::period;

  pendingPixel.id = rowID * resolution + columnID;
  pendingPixel.x = Application::state.piezoXVoltage * 0.320;
  pendingPixel.y = Application::state.piezoYVoltage * 0.320;
  pendingPixel.z = Application::state.piezoZVoltage * 0.320;
}
