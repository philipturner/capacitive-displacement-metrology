#pragma once

#include "State.h"

struct Application {
  static inline State state;

  static void setupSerial();

  static void setupSPI();

  static void setupI2C();

  static void updateCurrent();

  static void updatePiezoZVoltage(float voltage);

  static void updateBiasVoltage(float voltage);
};