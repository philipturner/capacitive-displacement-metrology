#include "Diagnostics/CapacitanceTracker.h"
#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
#include "Misc/Application.h"
#include "Misc/BlindStepper.h"
#include "Misc/Command.h"
#include "Time/KilohertzLoop.h"
#include "Util/FilterUtil.h"
#include <Arduino.h>

void kilohertzLoop();

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::updatePiezoZVoltage(BlindStepper::restPosition);

  Log::initialize();
  KilohertzLoop::initialize(kilohertzLoop, 12);
}

void loop() {
  delay(50);

  if (ErrorMessage::hasError()) {
    ErrorMessage::nullTerminate();

    Serial.println();
    Serial.println("error message:");
    Serial.println(ErrorMessage::buffer);
  }

  if (!ErrorMessage::hasError()) {
    Log::transmitBufferedSamples();
  }

  if (ErrorMessage::errorType != ErrorMessage::Type::fatal) {
    CommandTracker::processSerialInput();
  }
}

Command::Mode mode;
uint32_t dacTestChannel;
float dacTestVoltage;
BlindStepper blindStepper;

// Allocate one loop iteration of buffer time between command changes.
Command nextCommand;
bool resettingForModeChange = false;

void kilohertzLoop() {
  if (resettingForModeChange) {
    mode = nextCommand.mode;
    if (mode == Command::Mode::capacitanceReporting) {
      Application::capTracker = CapacitanceTracker(true);
    }
    if (mode == Command::Mode::blindStepping) {
      blindStepper = BlindStepper(nextCommand);
    }

    resettingForModeChange = false;
  } else {
    if (CommandTracker::nextCommand(nextCommand)) {
      resettingForModeChange = true;
    }
  }

  if (resettingForModeChange) {
    // Can only write to up to 3 DAC lines without exceeding the loop time.
    // For now, all commands touch the same number of DAC lines.
    Application::updatePiezoZVoltage(BlindStepper::restPosition);
    Application::updateBiasVoltage(0);
  } else {
    if (mode == Command::Mode::capacitanceReporting) {
      Application::updateCapacitanceTracker(/*regenerate=*/true);
    }
    if (mode == Command::Mode::blindStepping) {
      blindStepper.update();
    }
  }

  Application::updateCurrent();

  // Send data to the real-time monitor.
  if (ErrorMessage::hasError()) {
    return;
  }
  uint32_t iterationsPerLog = Log::targetLogPeriod / KilohertzLoop::period;
  if (KilohertzLoop::iterationID % iterationsPerLog == 0) {
    uint32_t ringIndex = Log::unsafeBufferedLogID % Log::logSize;

    if (mode == Command::Mode::blindStepping || 
        mode == Command::Mode::tipApproach) {
      Log::ringBuffers[0][ringIndex] = Application::state.filteredCurrent;
      Log::ringBuffers[1][ringIndex] = Application::state.piezoZVoltage;
      Log::ringBuffers[2][ringIndex] = Application::state.capacitance;
      Log::ringBuffers[3][ringIndex] = Application::state.phaseShift;
    } else {
      Log::ringBuffers[0][ringIndex] = Application::state.filteredCurrent;
      Log::ringBuffers[1][ringIndex] = Application::state.biasVoltage;
      Log::ringBuffers[2][ringIndex] = Application::state.capacitance;
      Log::ringBuffers[3][ringIndex] = Application::state.phaseShift;
    }

    Log::unsafeBufferedLogID += 1;
  }
}