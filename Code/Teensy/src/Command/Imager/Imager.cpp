#include "Imager.h"

#include "Filter/Creep/Harmonics.h"
#include "Time/KilohertzLoop.h"

Imager::Imager() {

}

Imager::Imager(Command command) {
  mode = getMode(command.alphaCode);
  resolutionMajor = command.attributes[0];
  resolutionMinor = command.attributes[1];
  pixelDimension = command.attributes[2] / float(resolutionMajor);

  if (resolutionMajor <= 32) {
    polynomialPeakTime = KilohertzLoopRound(1000);
  } else if (resolutionMajor <= 48) {
    polynomialPeakTime = KilohertzLoopRound(1500);
  } else {
    polynomialPeakTime = KilohertzLoopRound(2000);
  }

  trueResolutionMajor = getTrueResolutionMajor(
    resolutionMajor, polynomialPeakTime);
  
  settings = Imager::pendingSettings;
}

uint32_t Imager::getTrueResolutionMajor(
  uint32_t resolutionMajor,
  uint32_t polynomialPeakTime
) {
  uint32_t timePerRow = polynomialPeakTime + resolutionMajor * pixelTime;
  uint32_t iterationsPerRow = timePerRow / KilohertzLoop::period;
  if (Creep::Harmonics::isRoundTripSafe(iterationsPerRow)) {
    return resolutionMajor;
  }

  uint32_t adjustedIterations = Creep::Harmonics::nextSafeRoundTrip(iterationsPerRow);
  uint32_t scanLineTime = adjustedIterations * KilohertzLoop::period;
  scanLineTime -= polynomialPeakTime;

  uint32_t output = (scanLineTime + pixelTime - 1) / pixelTime;
  output = ((output + 1) / 2) * 2;
  return output;
}

uint32_t Imager::getRowTime() const {
  return polynomialPeakTime + trueResolutionMajor * pixelTime;
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

  return peakScaleFactor * (amplitudeNormalized - 0.5f);
}

uint32_t Imager::getMidPixelTime() {
  uint32_t divisibility = Imager::pixelTime / KilohertzLoop::period;
  if (divisibility % 2 == 0) {
    return pixelTime / 2;
  } else {
    uint32_t upperIteration = (divisibility / 2) + 1;
    return upperIteration * KilohertzLoop::period;
  }
}

float Imager::getCurrentStateWeight() {
  uint32_t divisibility = Imager::pixelTime / KilohertzLoop::period;
  if (divisibility % 2 == 0) {
    return 1.0;
  } else {
    return 0.5;
  }
}

float Imager::transformVoltageZ(float original) {
  return original;
}

float Imager::transformCurrent(float original) {
  return abs(original * 1e12f);
}

float2 Imager::getUncorrectedVoltageXY() const {
  return currentVoltageXY;
}