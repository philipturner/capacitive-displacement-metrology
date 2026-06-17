#include "SimpleScanner.h"

#include "Application/Application.h"
#include "Filter/Feedback.h"
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
  // Periods of loop destabilization correlate with systematic current jumps to
  // +10 nA.
  //
  // Try removing notch filter and slowing down feedback.
  if (false) {
    uint32_t currentTime = micros();
    uint32_t deltaTime = currentTime - previousTime;
    previousTime = currentTime;

    int32_t deltaExpected = int32_t(deltaTime) - 16;
    int32_t threshold = 1;

    if (abs(deltaExpected) >= threshold) {
      timingDisturance = deltaExpected;
      timeOfTimingDisturbance = KilohertzLoop::iterationID;
    }

    if (KilohertzLoop::iterationID - timeOfTimingDisturbance > 10) {
      timingDisturance = 0;
    }

    Application::state.spectroscopyTrigger = float(timingDisturance);
  }

  uint32_t time = Application::state.getTimeSinceModeStart();
  Application::updatePiezoVoltage(3, Feedback::getVoltage());

  float position;
  if (time < Imager::largeMoveRiseTime) {
    if (time == 0) {
      if (Application::state.piezoXVoltage != 0 ||
          Application::state.piezoYVoltage != 0) {
        Serial.println("Wrong starting position.");
        exit(0);
      }
    }
    
    float progress = float(time) / float(Imager::largeMoveRiseTime);
    progress = WaveUtil::thirdOrderSmoothstep(progress);

    float targetPosition = getPosition(0);
    position = progress * targetPosition;
  } else {
    position = getPosition(time - Imager::largeMoveRiseTime);
  }
  //Application::updatePiezoVoltage(2, position / 0.320);
  Application::updatePiezoVoltage(2, -40);
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