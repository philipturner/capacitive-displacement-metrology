#include "Imager.h"

#include "Application/Application.h"
#include "Diagnostics/Log.h"
#include "Filter/CreepFilter.h"
#include "Time/KilohertzLoop.h"
#include "Util/Feedback.h"
#include "Util/FilterUtil.h"
#include "Util/Interpolate.h"
#include <Arduino.h>

Imager::Imager() {

}

Imager::Imager(Command command) {
  mode = getMode(command.alphaCode);
  resolutionMajor = uint32_t(command.attributes[0]);
  resolutionMinor = uint32_t(command.attributes[0]);

  float imageSize = command.attributes[1];
  pixelDimension = imageSize / float(resolutionMajor);
  settings = Imager::pendingSettings;

  if (resolutionMajor <= 32) {
    polynomialPeakTime = 1008;
  } else if (resolutionMajor <= 48) {
    polynomialPeakTime = 1500;
  } else {
    polynomialPeakTime = 2004;
  }
  
  uint32_t capacity = (settings.electronicTimeLag / pixelTime) + 1;
  pixelBuffer = std::make_shared<PixelBuffer>(capacity);

  adjustScanFrequency();
}

void Imager::adjustScanFrequency() {
  uint32_t iterationsPerRow = getRowTime() / KilohertzLoop::period;
  if (CreepFilter::isRoundTripSafe(iterationsPerRow)) {
    return;
  }

  uint32_t adjustedIterations = CreepFilter::nextSafeRoundTrip(iterationsPerRow);
  uint32_t scanLineTime = adjustedIterations * KilohertzLoop::period;
  scanLineTime -= polynomialPeakTime;
  scanLineTime += pixelTime - 1;

  resolutionMajor = scanLineTime / pixelTime;
  resolutionMajor = ((resolutionMajor + 1) / 2) * 2;
}

void Imager::update() {
  uint32_t time = Application::state.getTimeSinceModeStart();
  Feedback::updatePiezoZ(false);

  uint32_t imageTime = getImageTime();
  uint32_t imageID = time / imageTime;
  uint32_t timeInImage = time % imageTime;

  if (timeInImage == 0) {
    // Reset the creep drift accumulator here.
    float x = Application::state.piezoXVoltage * 0.320;
    float y = Application::state.piezoYVoltage * 0.320;
    previousImageEnd = float2(x, y);
  }

  if (mode == Mode::image && imageID > 0) {
    return;
  }

  float2 position = getPosition(timeInImage, imageID);
  createPendingPixel(position, timeInImage);
  if (pixelBuffer->hasReadyPixel()) {
    pixelBuffer->flushReadyPixel();
  }

  Application::updatePiezoVoltage(1, position.x / 0.320);
  Application::updatePiezoVoltage(2, position.y / 0.320);
}

uint32_t Imager::getRowTime() const {
  return polynomialPeakTime + resolutionMajor * pixelTime;
}

uint32_t Imager::getImageTime() const {
  uint32_t output = 0;
  output += largeMoveRiseTime;
  output += settings.creepSettlingTime;
  output += resolutionMinor * getRowTime();
  output += polynomialPeakTime;
  return output;
}

float Imager::getPeakValue(float amplitudeNormalized) const {
  float linearPartVelocity = pixelDimension / float(pixelTime);
  float peakDefaultVelocity = 1 / float(polynomialPeakTime);
  float peakScaleFactor = linearPartVelocity / peakDefaultVelocity;

  return peakScaleFactor * (amplitudeNormalized - 0.5);
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
    float peakNormalized = FilterUtil::polynomialWaveOutskirt(0);
    float peakValue = getPeakValue(peakNormalized);

    float2 targetLocal;
    targetLocal.x = peakValue;
    targetLocal.y = 0.5 * pixelDimension;
    float2 targetPosition = getPosition(targetLocal, imageID);

    float progress = float(time) / float(largeMoveRiseTime);
    progress = FilterUtil::thirdOrderSmoothstep(progress);
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
        peakNormalized = FilterUtil::polynomialWaveOutskirt(progress);
      } else {
        peakNormalized = FilterUtil::polynomialWaveBend(progress);
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
    float peakNormalized = FilterUtil::polynomialWaveOutskirt(progress);

    x = getPeakValue(peakNormalized);
    y = (float(resolutionMinor) - 0.5) * pixelDimension;
  }

  float2 localPosition = float2(x, y);
  return getPosition(localPosition, imageID);
}

void Imager::createPendingPixel(float2 position, uint32_t timeInImage) {
  uint32_t time = timeInImage;
  if (time < largeMoveRiseTime) {
    return;
  } else {
    time -= largeMoveRiseTime;
  }

  if (time >= resolutionMinor * getRowTime()) {
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
    columnID = (resolutionMajor - 1) - columnID;
  }

  uint32_t majorBoundary = (resolutionMajor - resolutionMinor) / 2;
  if (columnID < majorBoundary) {
    return;
  } else {
    columnID -= majorBoundary;
  }
  if (columnID >= resolutionMinor) {
    return;
  }

  uint32_t id = rowID * resolutionMinor + columnID;
  uint32_t writeIterationID = KilohertzLoop::iterationID;
  writeIterationID += settings.electronicTimeLag / KilohertzLoop::period;
  
  PixelBuffer::Pixel pixel;
  pixel.writeIterationID = writeIterationID;
  pixel.id = id;
  pixel.x = position.x;
  pixel.y = position.y;
  pixel.z = Application::state.piezoZVoltage * 0.320;
  pixelBuffer->addPixel(pixel);
}
