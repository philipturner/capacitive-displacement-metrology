#include "SimpleScanner.h"

#include "Application/Application.h"
#include "Util/Feedback.h"
#include "Util/FilterUtil.h"
#include <Arduino.h>

SimpleScanner::SimpleScanner() {

}

SimpleScanner::SimpleScanner(Command command) {
  if (command.alphaCode == 'x') {
    channelID = 1;
  } else {
    channelID = 2;
  }

  uint32_t frequency = command.attributes[0];
  uint32_t period = uint32_t(1000 * 1000) / frequency;
  halfWavePeriod = period / 2;
  halfWavePeriod -= halfWavePeriod % 96;

  peakPeakAmplitude = float(command.attributes[1]) * 0.1;
}

bool SimpleScanner::checkAttributes(Command command) {
  uint32_t frequency = command.attributes[0];
  if (frequency == 0 || frequency > 10000) {
    CommandTracker::throwError(
      "Invalid frequency.",
      frequency);
    return false;
  }

  float peakPeakAmplitude = float(command.attributes[1]) * 0.1;
  if (peakPeakAmplitude <= 0 || peakPeakAmplitude > 270) {
    CommandTracker::throwError(
      "Invalid peak-peak amplitude.",
      int32_t(peakPeakAmplitude * 10));
    return false;
  }

  return true;
}

void SimpleScanner::update() {
  uint32_t time = Application::state.getTimeSinceModeStart();
  if (time == 0) {
    Application::updateBiasVoltage(Feedback::setpointVoltage);
  }
  Feedback::updatePiezoZ();

  if (!usePolynomialWave) {
    uint32_t wavePeriod = 2 * halfWavePeriod;
    uint32_t phase = time % wavePeriod;
    
    float phaseNormalized = float(phase) / float(wavePeriod);
    float position = FilterUtil::sineWave(phaseNormalized);
    position *= peakPeakAmplitude / 2;
    Application::updatePiezoVoltage(channelID, position / 0.320);
    return;
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
        peakValue = FilterUtil::polynomialWaveOutskirt(timeProgress);
      } else {
        peakValue = FilterUtil::polynomialWaveBend(timeProgress);
      }
      float position = peakScaleFactor * (peakValue - 0.5);

      if (i == 1) {
        position = peakPeakAmplitude - position;
      }
      position -= peakPeakAmplitude / 2;
      Application::updatePiezoVoltage(channelID, position / 0.320);
      return;
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
      Application::updatePiezoVoltage(channelID, position / 0.320);
      return;
    } else {
      time -= halfWavePeriod;
    }
  }

  Serial.println("This should never happen.");
  exit(0);
}