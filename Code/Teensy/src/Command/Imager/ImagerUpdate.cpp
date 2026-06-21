#include "Imager.h"

#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include "IC/DAC.h"
#include "Util/WaveUtil.h"
#include "Util/Interpolate.h"
#include <Arduino.h>

#include "Time/Profiling.h"

bool shouldContinueImaging(Imager::Mode mode, uint32_t imageID) {
  if (mode == Imager::Mode::image && imageID > 0) {
    return false;
  } else {
    return true;
  }
}

void Imager::update() {
  uint32_t time1 = ARM_DWT_CYCCNT;

  // 4.439-4.679, most common: 4.448
  // cache imageTime only: 4.418-4.673, most common: 4.428
  // cache rowTime only: most common: 4.431
  // cache both: most common: 4.426
  // using decomposition: most common: 4.411
  uint32_t time = Application::state.getTimeSinceModeStart();
  uint32_t imageTime = getImageTime();
  uint32_t imageID = time / imageTime;
  uint32_t timeInImage = time % imageTime;
  bool continueImaging = shouldContinueImaging(mode, imageID);
  auto decomposition = getTimeDecomposition(timeInImage);

  if (continueImaging) {
    if (timeInImage == 0) {
      float x = Application::state.piezoXVoltage * 0.320f;
      float y = Application::state.piezoYVoltage * 0.320f;
      previousImageEnd = float2(x, y);
    }
    
    if (decomposition.inSettlePeriod) {
      Application::creepFilter.resetDrift();
    }

    currentVoltageXY = getPosition(decomposition, imageID);
    currentVoltageXY /= 0.320f;
  }

  float2 creepCorrectedVoltageXY = currentVoltageXY;
  creepCorrectedVoltageXY += Application::creepFilter.getDriftCorrection();

  // latency to initialize Imager is 1.6-2.5 us
  // latency of the code below is 3.67 us
  if (time > 0) {
    Application::updatePiezoVoltage(1, creepCorrectedVoltageXY.x);
    DAC::enableSafeWait = false;
    Application::updatePiezoVoltage(2, creepCorrectedVoltageXY.y);
    DAC::enableSafeWait = true;
  }

  float2 dXY = currentVoltageXY - previousVoltageXY;
  Feedback::timeConstant = settings.feedbackTimeConstant;
  Application::correctZVoltage(dXY);
  Feedback::timeConstant = Feedback::defaultTimeConstant;

  pixelBuffer.updateCurrent();
  if (continueImaging) {
    int32_t pixelID = getPixelID(decomposition);
    if (pixelID != -1) {
      addPixel(pixelID);
    }
    if (pixelBuffer.hasReadyPixel()) {
      pixelBuffer.flushReadyPixel(settings.electronicTimeLag);
    }
  }

  previousVoltageXY = currentVoltageXY;

  uint32_t time5 = ARM_DWT_CYCCNT;

  if (KilohertzLoop::iterationID % 1997 == 0 || time == 0) {
    Serial.print("imager.update() ");
    Profiling::display(time1, time5);
    Serial.print(time);
    Serial.println();
  }
}

float2 Imager::getPosition(float2 localPosition, uint32_t imageID) {
  float2 output = localPosition;
  output.x += -0.5f * float(trueResolutionMajor) * pixelDimension;
  output.y += -0.5f * float(resolutionMinor) * pixelDimension;

  if (settings.majorAxis == 1) {
    output = float2(output.y, output.x);
  }

  if (mode == Mode::dualVideo && (imageID % 2 == 1)) {
    output += settings.centers[1];
  } else {
    output += settings.centers[0];
  }

  return output;
}

float2 Imager::getPosition(TimeDecomposition decomposition, uint32_t imageID) {
  float timeLeft = float(decomposition.timeLeft);

  if (decomposition.inSettlePeriod) {
    float peakNormalized = WaveUtil::polynomialWaveOutskirt(0);
    float peakValue = getPeakValue(peakNormalized);

    float2 targetLocal;
    targetLocal.x = peakValue;
    targetLocal.y = 0.5f * pixelDimension;
    float2 targetPosition = getPosition(targetLocal, imageID);

    float progress = timeLeft / float(largeMoveRiseTime);
    progress = WaveUtil::thirdOrderSmoothstep(progress);
    return interpolate(previousImageEnd, targetPosition, progress);
  }

  float x;
  float y;
  if (decomposition.rowID < resolutionMinor) {
    if (decomposition.inPolynomialPeak) {
      float progress = timeLeft / float(polynomialPeakTime);
      float peakNormalized;
      if (decomposition.rowID == 0) {
        peakNormalized = WaveUtil::polynomialWaveOutskirt(progress);
      } else {
        peakNormalized = WaveUtil::polynomialWaveBend(progress);
      }
      x = getPeakValue(peakNormalized);
      
      float startRow = max(0.0f, float(decomposition.rowID) - 1.0f);
      float endRow = float(decomposition.rowID);
      float row = interpolate(startRow, endRow, progress);
      y = (row + 0.5f) * pixelDimension;
    } else {
      x = timeLeft / float(pixelTime) * pixelDimension;
      y = (float(decomposition.rowID) + 0.5f) * pixelDimension;
    }

    if (decomposition.rowID % 2 == 1) {
      x = float(trueResolutionMajor) * pixelDimension - x;
    }
  } else {
    float progress = 1.0f - timeLeft / float(polynomialPeakTime);
    float peakNormalized = WaveUtil::polynomialWaveOutskirt(progress);

    x = getPeakValue(peakNormalized);
    y = (float(resolutionMinor) - 0.5f) * pixelDimension;
  }

  float2 localPosition = float2(x, y);
  return getPosition(localPosition, imageID);
}

int32_t Imager::getPixelID(TimeDecomposition decomposition) {
  if (decomposition.inSettlePeriod ||
      decomposition.inPolynomialPeak ||
      decomposition.rowID >= resolutionMinor) {
    return -1;
  }

  uint32_t columnID = decomposition.timeLeft / pixelTime;
  uint32_t timeInPixel = decomposition.timeLeft - columnID * pixelTime;
  if (timeInPixel != Imager::getMidPixelTime()) {
    return -1;
  }

  if (decomposition.rowID % 2 == 1) {
    columnID = (trueResolutionMajor - 1) - columnID;
  }

  uint32_t majorBoundary = (trueResolutionMajor - resolutionMajor) / 2;
  if (columnID < majorBoundary) {
    return -1;
  } else {
    columnID -= majorBoundary;
  }
  if (columnID >= resolutionMajor) {
    return -1;
  }

  return decomposition.rowID * resolutionMajor + columnID;
}

void Imager::addPixel(uint32_t pixelID) {
  PixelBuffer::Pixel pixel;
  pixel.id = pixelID;

  uint32_t writeIterationID = KilohertzLoop::iterationID;
  writeIterationID += KilohertzLoopRound(settings.electronicTimeLag) / KilohertzLoop::period;
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
