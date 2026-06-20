#include "Application.h"

#include "Command/Tilt/Settings.h"
#include "Filter/Feedback.h"
#include "IC/DAC.h"
#include "IC/PA95.h"

void Application::updateBiasVoltage(float voltage) {
  float dV = voltage - state.biasVoltage;
  float C = 50e-15;
  state.addSpike(dV, C);

  state.biasVoltage = voltage;
  DAC::enableSafeWait = false;
  DAC2::writeVoltage(0, voltage);
  DAC::enableSafeWait = true;
}

void Application::updatePiezoVoltage(uint32_t channelID, float voltage) {
  float C = 0;
  float previousVoltage = 0;
  if (channelID == 1) {
    C = 13e-18;
    previousVoltage = state.piezoXVoltage;
    state.piezoXVoltage = voltage;
  } else if (channelID == 2) {
    C = 45e-18;
    previousVoltage = state.piezoYVoltage;
    state.piezoYVoltage = voltage;
  } else if (channelID == 3) {
    C = 27e-18;
    previousVoltage = state.piezoZVoltage;
    state.piezoZVoltage = voltage;
  }
  if (channelID != 3) {
    PA95::writeVoltage(channelID, voltage);
  }

  float dV = voltage - previousVoltage;
  state.addSpike(dV, C);
}

void Application::updatePiezoZDeferred() {
  DAC::enableSafeWait = false;
  PA95::writeVoltage(3, state.piezoZVoltage);
  DAC::enableSafeWait = true;
}

void Application::updateCapacitanceTracker(bool regenerate) {
  // This only writes to capacitance and phaseShift if the mode is
  // transitioning from 'measuring' to 'finished'.
  capTracker.update();
  
  auto state = capTracker.getCurrentState();
  if (state == CapacitanceTracker::State::finished) {
    if (!regenerate) {
      return;
    }

    capTracker = CapacitanceTracker(true);
    capTracker.update();
  }

  float biasVoltage = capTracker.getBiasVoltage();
  Application::updateBiasVoltage(biasVoltage);

  float filteredCurrent = Application::state.filteredCurrent;
  capTracker.integrate(filteredCurrent);
}

void Application::setBiasForFeedback() {
  updateBiasVoltage(Feedback::setpointVoltage);
}

void Application::correctZVoltage() {
  float2 dXY;
  dXY.x = state.piezoXVoltage - state.previous.x;
  dXY.y = state.piezoYVoltage - state.previous.y;
  correctZVoltage(dXY);
}

void Application::correctZVoltage(float2 dXY) {
  float newVoltageZ = state.piezoZVoltage;
  newVoltageZ += Feedback::getVoltageCorrection(state.current);
  newVoltageZ += Tilt::Settings::slope.x * dXY.x;
  newVoltageZ += Tilt::Settings::slope.y * dXY.y;

  newVoltageZ = min(newVoltageZ, 270);
  newVoltageZ = max(newVoltageZ, -80);
  updatePiezoVoltage(3, newVoltageZ);
}