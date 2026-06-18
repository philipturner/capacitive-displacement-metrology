#include "Imager.h"

#include "Filter/Creep/Harmonics.h"
#include "Time/KilohertzLoop.h"

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
    polynomialPeakTime = KilohertzLoopRound(1000);
  } else if (resolutionMajor <= 48) {
    polynomialPeakTime = KilohertzLoopRound(1500);
  } else {
    polynomialPeakTime = KilohertzLoopRound(2000);
  }
  
  adjustScanFrequency();
}

void Imager::adjustScanFrequency() {
  uint32_t iterationsPerRow = getRowTime() / KilohertzLoop::period;
  if (Creep::Harmonics::isRoundTripSafe(iterationsPerRow)) {
    return;
  }

  uint32_t adjustedIterations = Creep::Harmonics::nextSafeRoundTrip(iterationsPerRow);
  uint32_t scanLineTime = adjustedIterations * KilohertzLoop::period;
  scanLineTime -= polynomialPeakTime;
  scanLineTime += pixelTime - 1;

  resolutionMajor = scanLineTime / pixelTime;
  resolutionMajor = ((resolutionMajor + 1) / 2) * 2;
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
  return abs(original * 1e12);
}