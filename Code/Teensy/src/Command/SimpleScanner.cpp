#include "SimpleScanner.h"

#include "Application/Application.h"
#include "Util/Interpolate.h"
#include "Util/WaveUtil.h"
#include <Arduino.h>

SimpleScanner::SimpleScanner() {

}

SimpleScanner::SimpleScanner(Command command) {
  if (command.alphaCode == 'x') {
    channelID = 1;
  } else {
    channelID = 2;
  }

  float frequency = command.attributes[0];
  uint32_t period = float(1e6) / frequency;
  halfWavePeriod = period / 2;
  halfWavePeriod += Imager::pixelTime - 1;
  halfWavePeriod -= halfWavePeriod % Imager::pixelTime;

  peakPeakAmplitude = command.attributes[1];
}

void SimpleScanner::update() {
  uint32_t time = Application::state.getTimeSinceModeStart();
  
  float position;
  if (time < Imager::largeMoveRiseTime) {
    float progress = float(time) / float(Imager::largeMoveRiseTime);
    progress = WaveUtil::thirdOrderSmoothstep(progress);

    float targetPosition = getPosition(0);
    position = interpolate(float(0), targetPosition, progress);
  } else {
    position = getPosition(time - Imager::largeMoveRiseTime);
  }
  Application::updatePiezoVoltage(channelID, position / 0.320f);
  Application::correctZVoltage();
}

float SimpleScanner::getPosition(uint32_t inputTime) const {
  uint32_t time = inputTime;
  
  if (!usePolynomialWave) {
    uint32_t wavePeriod = 2 * halfWavePeriod;
    uint32_t phase = time % wavePeriod;
    
    float phaseNormalized = float(phase) / float(wavePeriod);
    float position = WaveUtil::triangleWave(phaseNormalized);
    position *= peakPeakAmplitude / 2;
    return position;
  }

  float linearPartVelocity = peakPeakAmplitude / float(halfWavePeriod);
  float peakDefaultVelocity = 1 / float(polynomialPeakTime);
  float peakScaleFactor = linearPartVelocity / peakDefaultVelocity;

  bool needsOutskirt = (time < polynomialPeakTime);
  uint32_t fullPeriod = 2 * halfWavePeriod + 2 * polynomialPeakTime;
  time = time % fullPeriod;

  for (uint32_t i = 0; i < 2; ++i) {
    if (time < polynomialPeakTime) {
      float timeProgress = float(time) / float(polynomialPeakTime);
      float peakValue;
      if (needsOutskirt) {
        peakValue = WaveUtil::polynomialWaveOutskirt(timeProgress);
      } else {
        peakValue = WaveUtil::polynomialWaveBend(timeProgress);
      }
      float position = peakScaleFactor * (peakValue - 0.5);

      if (i == 1) {
        position = peakPeakAmplitude - position;
      }
      position -= peakPeakAmplitude / 2;
      return position;
    } else {
      time -= polynomialPeakTime;
    }

    if (time < halfWavePeriod) {
      float timeProgress = float(time) / float(halfWavePeriod);
      float position = timeProgress * peakPeakAmplitude;

      if (i == 1) {
        position = peakPeakAmplitude - position;
      }
      position -= peakPeakAmplitude / 2;
      return position;
    } else {
      time -= halfWavePeriod;
    }
  }

  Serial.println("This should never happen.");
  exit(0);
}