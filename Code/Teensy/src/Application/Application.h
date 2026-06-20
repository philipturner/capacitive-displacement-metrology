#pragma once

#include "Application/ApplicationState.h"
#include "Command/Imager/Imager.h"
#include "Command/Tilt/Calculator.h"
#include "Command/BlindStepper.h"
#include "Command/DACTester.h"
#include "Command/SimpleScanner.h"
#include "Command/Spectroscopy.h"
#include "Command/TipApproacher.h"
#include "Diagnostics/CapacitanceTracker.h"
#include "Filter/Creep/Filter.h"

struct Application {
  static inline ApplicationState state;
  static inline Command::Mode mode;
  static inline CapacitanceTracker capTracker;
  static inline Creep::Filter creepFilter;

  static inline DACTester dacTester;
  static inline BlindStepper blindStepper;
  static inline TipApproacher tipApproacher;
  static inline Spectroscopy spectroscopy;
  static inline SimpleScanner simpleScanner;
  static inline Imager imager;
  static inline Tilt::Calculator tiltCalculator;

  static void initialize();
  static void setupSerial();
  static void setupSPI();
  static void setupI2C();

  static void updateBiasVoltage(float voltage);
  static void updatePiezoVoltage(uint32_t channelID, float voltage);
  static void updatePiezoZDeferred();

  static void updateCapacitanceTracker(bool regenerate);

  static void setBiasForFeedback();
  static void correctZVoltage();
  static void correctZVoltage(float2 dXY);

  static void logHistoryMessage();
};