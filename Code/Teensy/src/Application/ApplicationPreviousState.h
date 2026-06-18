#pragma once

#include "ApplicationState.h"

struct ApplicationPreviousState {
  float piezoXVoltage = 0;
  float piezoYVoltage = 0;
  float piezoZVoltage = 0;
  float filteredCurrent = 0;

  ApplicationPreviousState(ApplicationState state) {
    piezoXVoltage = state.piezoXVoltage;
    piezoYVoltage = state.piezoYVoltage;
    piezoZVoltage = state.piezoZVoltage;
    filteredCurrent = state.filteredCurrent;
  }
};