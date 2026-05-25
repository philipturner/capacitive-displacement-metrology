#include "State.h"

#include "IC/ADC.h"
#include "Time/KilohertzLoop.h"
#include "Util/FilterUtil.h"

void State::updateCurrent() {
  auto conversion = ADC::readVoltage();
  current = -conversion.voltage / 1e9;

  float alpha = FilterUtil::getLowpassAlpha(10000, KilohertzLoop::period);
  filteredCurrent *= 1 - alpha;
  filteredCurrent += alpha * current;

  currentMaximum = max(currentMaximum, abs(current));
}

void State::addSpike(float dV, float C) {
  float dt = float(KilohertzLoop::period) * 1e-6;
  float I = C * (dV / dt);
  currentSpike[9] += abs(I);
}

void State::updateCurrentSpike() {
  float alpha = FilterUtil::getLowpassAlpha(15000, KilohertzLoop::period);
  filteredCurrentSpike *= 1 - alpha;
  filteredCurrentSpike += alpha * currentSpike[8];

  for (uint32_t i = 0; i < 9; ++i) {
    currentSpike[i] = currentSpike[i + 1];
  }
  currentSpike[9] = 0;
}

float State::getPredictedCurrentSpike() const {
  float maxCurrent = 0;
  for (uint32_t i = 0; i < 9; ++i) {
    float historyCurrent = currentSpike[i];
    maxCurrent = max(maxCurrent, historyCurrent);
  }
  maxCurrent = max(maxCurrent, filteredCurrentSpike);
  return maxCurrent;
}

float State::extractCurrentMaximum() {
  float output = currentMaximum;
  currentMaximum = 0;
  return output;
}