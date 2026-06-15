#pragma once

#include "Application/State.h"
#include "Command/BlindStepper.h"
#include "Command/DACTester.h"
#include "Command/Imager/Imager.h"
#include "Command/SimpleScanner.h"
#include "Command/Spectroscopy.h"
#include "Command/TipApproacher.h"
#include "Diagnostics/CapacitanceTracker.h"
#include "Filter/Creep/Filter.h"

struct Application {
  static inline uint32_t startTime = 0;
  static inline uint32_t midTime = 0;
  static inline uint32_t endTime = 0;

  static inline State state;
  static inline Command::Mode mode;
  static inline CapacitanceTracker capTracker;
  static inline Creep::Filter creepFilter;

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

  static void logNormalMessage();
};