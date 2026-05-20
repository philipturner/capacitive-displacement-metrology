#pragma once

#include "Diagnostics/CapacitanceTracker.h"
#include "Misc/State.h"

struct Application {
  static inline State state;
  static inline CapacitanceTracker capTracker;

  static void setupSerial();

  static void setupSPI();

  static void setupI2C();

  static void updateCurrent();

  static void updatePiezoZVoltage(float voltage);

  static void updateBiasVoltage(float voltage);

  static void updateCapacitanceTracker(bool regenerate);
};