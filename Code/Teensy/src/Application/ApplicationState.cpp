#include "ApplicationState.h"

#include "Filter/FirstOrderLowpassFilter.h"
#include "IC/ADC.h"
#include "Time/KilohertzLoop.h"
#include "Util/Emulation.h"
#include <Arduino.h>

void ApplicationState::updateCurrent(bool useADC) {
  if (emulateCurrent) {
    Emulation::updateSecondOrderFilter(piezoZVoltage);
    current = Emulation::getCurrent(piezoXVoltage, piezoYVoltage);
  } else if (useADC) {
    auto conversion = ADC::readVoltage();
    current = -conversion.voltage / 1e9f;
  } else {
    current = 0;
  }

  float alpha = FirstOrderLowpassFilter::getAlpha(10000);
  filteredCurrent *= 1 - alpha;
  filteredCurrent += alpha * current;

  currentMaximum = max(currentMaximum, abs(current));
  updateCurrentSpike();
}

void ApplicationState::addSpike(float dV, float C) {
  float dt = float(KilohertzLoop::period) * 1e-6f;
  float I = C * (dV / dt);
  currentSpike[9] += abs(I);
}

void ApplicationState::updateCurrentSpike() {
  float alpha = FirstOrderLowpassFilter::getAlpha(15000);
  filteredCurrentSpike *= 1.0f - alpha;
  filteredCurrentSpike += alpha * currentSpike[8];

  for (uint32_t i = 0; i < 9; ++i) {
    currentSpike[i] = currentSpike[i + 1];
  }
  currentSpike[9] = 0;
}

float ApplicationState::getPredictedCurrentSpike() const {
  float maxCurrent = 0;
  for (uint32_t i = 0; i < 9; ++i) {
    float historyCurrent = currentSpike[i];
    maxCurrent = max(maxCurrent, historyCurrent);
  }
  maxCurrent = max(maxCurrent, filteredCurrentSpike);
  return maxCurrent;
}

float ApplicationState::extractCurrentMaximum() {
  float output = currentMaximum;
  currentMaximum = 0;
  return output;
}

uint32_t ApplicationState::getTimeSinceModeStart() {
  uint32_t deltaIters = KilohertzLoop::iterationID;
  deltaIters -= modeStartIterationID;
  return deltaIters * KilohertzLoop::period;
}