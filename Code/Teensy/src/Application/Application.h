#pragma once

#include "Application/State.h"
#include "Command/BlindStepper.h"
#include "Command/Command.h"
#include "Command/DACTester.h"
#include "Command/Imager/Imager.h"
#include "Command/SimpleScanner.h"
#include "Command/Spectroscopy.h"
#include "Command/TipApproacher.h"
#include "Diagnostics/CapacitanceTracker.h"

struct Application {
  static inline State state;
  static inline Command::Mode mode;
  static inline CapacitanceTracker capTracker;

  static inline DACTester dacTester;
  static inline BlindStepper blindStepper;
  static inline TipApproacher tipApproacher;
  static inline Spectroscopy spectroscopy;
  static inline SimpleScanner simpleScanner;
  static inline Imager imager;

  static void initialize();

  static void setupSerial();

  static void setupSPI();

  static void setupI2C();

  static void updatePiezoVoltage(uint32_t channelID, float voltage);

  static void updateBiasVoltage(float voltage);

  static void updateCapacitanceTracker(bool regenerate);

  static void logNormalMessage(
    uint32_t capacitanceUpdateCountAtModeChange);
};