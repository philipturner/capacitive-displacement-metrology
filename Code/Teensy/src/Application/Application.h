#pragma once

#include "Application/State.h"
#include "Diagnostics/CapacitanceTracker.h"

struct Application {
  static inline State state;
  static inline CapacitanceTracker capTracker;

  static void setupSerial();

  static void setupSPI();

  static void setupI2C();

  static void updateCurrent();

  static void updatePiezoVoltage(uint32_t channelID, float voltage);

  static void updateBiasVoltage(float voltage);

  static void updateCapacitanceTracker(bool regenerate);
};