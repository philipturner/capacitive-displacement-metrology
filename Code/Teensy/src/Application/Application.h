#pragma once

#include "Application/State.h"
#include "Command/BlindStepper.h"
#include "Command/Command.h"
#include "Command/DACTester.h"
#include "Command/Spectroscopy.h"
#include "Command/TipApproacher.h"
#include "Diagnostics/CapacitanceTracker.h"
#include "Util/Feedback.h"

struct Application {
  static inline State state;
  static inline Command::Mode mode;
  static inline Feedback feedback;

  static inline DACTester dacTester;
  static inline CapacitanceTracker capTracker;
  static inline BlindStepper blindStepper;
  static inline TipApproacher tipApproacher;
  static inline Spectroscopy spectroscopy;

  static void initialize();

  static void setupSerial();

  static void setupSPI();

  static void setupI2C();

  static void updatePiezoVoltage(uint32_t channelID, float voltage);

  static void updateBiasVoltage(float voltage);

  static void updateCapacitanceTracker(bool regenerate);

  static void logNormalMessage();
};