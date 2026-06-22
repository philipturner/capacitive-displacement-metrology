#include "Imager.h"

#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include "IC/DAC.h"
#include "Util/WaveUtil.h"
#include "Util/Interpolate.h"
#include <Arduino.h>

#include "Diagnostics/Log.h" // debugging; calibrating hysteresis width

bool shouldContinueImaging(Imager::Mode mode, uint32_t imageID) {
  if (mode == Imager::Mode::image && imageID > 0) {
    return false;
  } else {
    return true;
  }
}

void Imager::update() {
  // 4.439-4.679, most common: 4.448 (repeated this and got most common: 4.429)
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

  if (timeInImage == 0) {
    float x = Application::state.piezoXVoltage * 0.320f;
    float y = Application::state.piezoYVoltage * 0.320f;
    previousImageEnd = float2(x, y);
  }
  
  if (decomposition.inSettlePeriod) {
    Application::creepFilter.resetDrift();
  }

  if (continueImaging) {
    currentVoltageXY = getPosition(decomposition, imageID);
    currentVoltageXY /= 0.320f;
  }

  // latency to initialize Imager is 1.6-2.5 us
  // latency of the code below is 3.67 us
  if (time > 0 && continueImaging) {
    float2 creepCorrectedVoltageXY = currentVoltageXY;
    if (continueImaging && !decomposition.inSettlePeriod) {
      creepCorrectedVoltageXY += Application::creepFilter.getDriftCorrection();
      Application::creepFilter.setEarlyScaleCorrection(creepCorrectedVoltageXY);
      creepCorrectedVoltageXY += Application::creepFilter.earlyScaleCorrection;
    }

    if (false) {
      if (!decomposition.inSettlePeriod &&
          !decomposition.inPolynomialPeak &&
          decomposition.rowID < resolutionMinor) {
        uint32_t halfTime = pixelTime * (trueResolutionMajor / 2);
        if (decomposition.timeLeft == 0 || decomposition.timeLeft == halfTime) {
          float2 corrected = creepCorrectedVoltageXY;
          corrected += Application::creepFilter.getDriftCorrection();

  /*
  spectroscopy, 18.0, 0.5, -0.048452377, -0.04305458, 0.0, 
  spectroscopy, 19.0, 0.5, 0.049901962, 0.044504166, 0.0, 

  spectroscopy, 18.0, 0.5, -0.048817635, -0.043419838, 0.0, 
  spectroscopy, 19.0, 0.5, 0.050914764, 0.045516014, 0.0, 

  spectroscopy, 18.0, 0.5, -0.046614647, -0.04121685, 0.0, 
  spectroscopy, 19.0, 0.5, 0.049035072, 0.043636322, 0.0, 

  spectroscopy, 18.0, 0.5, -0.047104836, -0.04170704, 0.0, 
  spectroscopy, 19.0, 0.5, 0.049146652, 0.043748856, 0.0, 



  spectroscopy, 18.0, 0.5, -0.047520638, -0.047520638, 0.0, 
  spectroscopy, 19.0, 0.5, 0.04938984, 0.04938984, 0.0, 

  spectroscopy, 18.0, 0.5, -0.04759693, -0.04759693, 0.0, 
  spectroscopy, 19.0, 0.5, 0.052124977, 0.052124977, 0.0, 

  spectroscopy, 18.0, 0.5, -0.048395157, -0.048395157, 0.0, 
  spectroscopy, 19.0, 0.5, 0.051628113, 0.051628113, 0.0, 

  spectroscopy, 18.0, 0.5, -0.048401833, -0.048401833, 0.0, 
  spectroscopy, 19.0, 0.5, 0.04969406, 0.04969406, 0.0, 

  spectroscopy, 18.0, 0.5, -0.04820156, -0.04820156, -0.002698958, 
  spectroscopy, 19.0, 0.5, 0.050121307, 0.050121307, 0.002698958, 



  spectroscopy, 18.0, 0.4972992, -0.053388596, -0.0479908, 0.0, 
  spectroscopy, 19.0, 0.50268555, 0.055295944, 0.049897194, 0.0,

  spectroscopy, 18.0, 0.4972992, -0.05293274, -0.047534943, -0.002698958, 
  spectroscopy, 19.0, 0.50268555, 0.05379486, 0.048397064, 0.002698958, 

  spectroscopy, 18.0, 0.4972992, -0.052775383, -0.047377586, -0.002698958, 
  spectroscopy, 19.0, 0.50268555, 0.05762291, 0.052225113, 0.002698958, 

  spectroscopy, 18.0, 0.4972992, -0.05162716, -0.04622841, -0.002698958, 
  spectroscopy, 19.0, 0.50268555, 0.056581497, 0.051182747, 0.002698958, 

  spectroscopy, 18.0, 0.4972992, -0.052754402, -0.047356606, -0.002698958, 
  spectroscopy, 19.0, 0.50268555, 0.05486393, 0.049466133, 0.002698958, 
  */

          float midPosition = corrected.x * 0.320f;

          if (decomposition.timeLeft == halfTime) {
            if (trueResolutionMajor == resolutionMajor) {
              if (decomposition.rowID >= 1) {
                float dx = midPosition - previousRowMidPosition;
                Log::write(
                  Log::Flags::spectroscopy,
                  float(decomposition.rowID),
                  creepCorrectedVoltageXY.x * 0.320f,
                  dx,
                  Application::creepFilter.earlyScaleCorrection.x * 0.320f);
              }
            }
            previousRowMidPosition = midPosition;
          }
        }
      }
    }

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
