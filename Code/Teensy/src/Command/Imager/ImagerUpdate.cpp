#include "Imager.h"

#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include "IC/DAC.h"
#include "Util/WaveUtil.h"
#include "Util/Interpolate.h"
#include <Arduino.h>

bool shouldContinueImaging(Imager::Mode mode, uint32_t imageID) {
  if (mode == Imager::Mode::image && imageID > 0) {
    return false;
  } else {
    return true;
  }
}

void Imager::update() {
  uint32_t time = Application::state.getTimeSinceModeStart();  
  uint32_t imageTime = getImageTime();
  uint32_t imageID = time / imageTime;
  uint32_t timeInImage = time % imageTime;
  bool continueImaging = shouldContinueImaging(mode, imageID);

  if (continueImaging) {
    if (timeInImage == 0) {
      float x = Application::state.piezoXVoltage * 0.320;
      float y = Application::state.piezoYVoltage * 0.320;
      previousImageEnd = float2(x, y);
    }
    
    if (timeInImage < largeMoveRiseTime + settings.creepSettlingTime) {
      Application::creepFilter.futureAccumulatedDrift = float2(0);
    }

    currentVoltageXY = getPosition(timeInImage, imageID);
    currentVoltageXY *= float(1 / 0.320);
  }

  float2 creepCorrectedVoltageXY = currentVoltageXY;
  creepCorrectedVoltageXY += -1 * Application::creepFilter.futureAccumulatedDrift;
  Application::updatePiezoVoltage(1, creepCorrectedVoltageXY.x);
  DAC::enableSafeWait = false;
  Application::updatePiezoVoltage(2, creepCorrectedVoltageXY.y);
  DAC::enableSafeWait = true;

  float2 dXY = currentVoltageXY + (-1 * previousVoltageXY);
  Application::correctZVoltage(dXY);

  if (continueImaging) {
    int32_t pixelID = getPixelID(timeInImage);
    if (pixelID != -1) {
      addPixel(pixelID);
    }
    if (pixelBuffer.hasReadyPixel()) {
      pixelBuffer.flushReadyPixel();
    }
  }

  previousVoltageXY = currentVoltageXY;
}

float2 Imager::getPosition(float2 localPosition, uint32_t imageID) {
  float2 output = localPosition;
  output.x += -0.5 * float(resolutionMajor) * pixelDimension;
  output.y += -0.5 * float(resolutionMinor) * pixelDimension;

  if (settings.dominantAxis == 1) {
    output = float2(output.y, output.x);
  }

  if (mode == Mode::dualVideo && (imageID % 2 == 1)) {
    output += settings.centers[1];
  } else {
    output += settings.centers[0];
  }

  return output;
}

float2 Imager::getPosition(uint32_t timeInImage, uint32_t imageID) {
  uint32_t time = timeInImage;
  if (time < largeMoveRiseTime + settings.creepSettlingTime) {
    float peakNormalized = WaveUtil::polynomialWaveOutskirt(0);
    float peakValue = getPeakValue(peakNormalized);

    float2 targetLocal;
    targetLocal.x = peakValue;
    targetLocal.y = 0.5 * pixelDimension;
    float2 targetPosition = getPosition(targetLocal, imageID);

    float progress = float(time) / float(largeMoveRiseTime);
    progress = WaveUtil::thirdOrderSmoothstep(progress);
    return interpolate(previousImageEnd, targetPosition, progress);
  } else {
    time -= largeMoveRiseTime + settings.creepSettlingTime;
  }

  float x;
  float y;
  if (time < resolutionMinor * getRowTime()) {
    uint32_t rowID = time / getRowTime();
    time = time % getRowTime();

    if (time < polynomialPeakTime) {
      float progress = float(time) / float(polynomialPeakTime);
      float peakNormalized;
      if (rowID == 0) {
        peakNormalized = WaveUtil::polynomialWaveOutskirt(progress);
      } else {
        peakNormalized = WaveUtil::polynomialWaveBend(progress);
      }
      x = getPeakValue(peakNormalized);
      
      float startRow = max(0, float(rowID) - 1);
      float endRow = float(rowID);
      float row = interpolate(startRow, endRow, progress);
      y = (row + 0.5) * pixelDimension;
    } else {
      time -= polynomialPeakTime;

      x = float(time) / float(pixelTime) * pixelDimension;
      y = (float(rowID) + 0.5) * pixelDimension;
    }

    if (rowID % 2 == 1) {
      x = float(resolutionMajor) * pixelDimension - x;
    }
  } else {
    time -= resolutionMinor * getRowTime();
    time = min(time, polynomialPeakTime);

    float progress = 1 - float(time) / float(polynomialPeakTime);
    float peakNormalized = WaveUtil::polynomialWaveOutskirt(progress);

    x = getPeakValue(peakNormalized);
    y = (float(resolutionMinor) - 0.5) * pixelDimension;
  }

  float2 localPosition = float2(x, y);
  return getPosition(localPosition, imageID);
}

int32_t Imager::getPixelID(uint32_t timeInImage) {
  uint32_t time = timeInImage;
  if (time < largeMoveRiseTime + settings.creepSettlingTime) {
    return -1;
  } else {
    time -= largeMoveRiseTime + settings.creepSettlingTime;
  }

  if (time >= resolutionMinor * getRowTime()) {
    return -1;
  }

  uint32_t rowID = time / getRowTime();
  time = time % getRowTime();

  if (time < polynomialPeakTime) {
    return -1;
  } else {
    time -= polynomialPeakTime;
  }

  uint32_t columnID = time / pixelTime;
  time = time % pixelTime;
  if (time != Imager::getMidPixelTime()) {
    return -1;
  }

  if (rowID % 2 == 1) {
    columnID = (resolutionMajor - 1) - columnID;
  }

  uint32_t majorBoundary = (resolutionMajor - resolutionMinor) / 2;
  if (columnID < majorBoundary) {
    return -1;
  } else {
    columnID -= majorBoundary;
  }
  if (columnID >= resolutionMinor) {
    return -1;
  }

  return rowID * resolutionMinor + columnID;
}

void Imager::addPixel(uint32_t pixelID) {
  PixelBuffer::Pixel pixel;
  pixel.id = pixelID;

  uint32_t writeIterationID = KilohertzLoop::iterationID;
  writeIterationID += settings.electronicTimeLag / KilohertzLoop::period;
  pixel.writeIterationID = writeIterationID;

  float progress = Imager::getCurrentStateWeight();
  float2 voltageXY = interpolate(previousVoltageXY, currentVoltageXY, progress);
  pixel.voltageX = voltageXY.x;
  pixel.voltageY = voltageXY.y;

  float previousZ = Application::state.previous.z;
  float currentZ = Application::state.piezoZVoltage;
  pixel.voltageZ = interpolate(previousZ, currentZ, progress);

  pixelBuffer.addPixel(pixel);
}
