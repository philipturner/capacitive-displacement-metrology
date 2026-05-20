#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
#include "Misc/Application.h"
#include "Misc/Command.h"
#include "Time/KilohertzLoop.h"
#include "Util/FilterUtil.h"
#include <Arduino.h>

void kilohertzLoop();

void setup() {
  Application::setupSerial();
  Application::setupSPI();
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

enum class BlindSteppingMode {
  up = 0,
  down = 1,
  capacitance = 2,
};
BlindSteppingMode getBlindSteppingMode(uint32_t code) {
  char character = char(code);
  if (character == 'u') {
    return BlindSteppingMode::up;
  } else if (character == 'd') {
    return BlindSteppingMode::down;
  } else if (character == 'c') {
    return BlindSteppingMode::capacitance;
  } else {
    Serial.println("This should never happen.");
    exit(0);
  }
}

Command::Mode mode;
BlindSteppingMode blindSteppingMode;
float capacitanceThreshold; // units: pF
uint32_t stepsPerCheck;

// Allocate one loop iteration of buffer time between command changes.
Command nextCommand;
bool resettingForModeChange = false;

void kilohertzLoop() {
  if (resettingForModeChange) {
    resettingForModeChange = false;

    mode = nextCommand.mode;
    if (mode == Command::Mode::blindStepping) {
      blindSteppingMode = getBlindSteppingMode(nextCommand.attributes[0]);
      if (blindSteppingMode == BlindSteppingMode::up ||
          blindSteppingMode == BlindSteppingMode::down) {
        stepsPerCheck = nextCommand.attributes[1];
      } else if (blindSteppingMode == BlindSteppingMode::capacitance) {
        capacitanceThreshold = float(nextCommand.attributes[1]) / 10000;
        stepsPerCheck = nextCommand.attributes[2];
      }
    }
  } else {
    if (CommandTracker::nextCommand(nextCommand)) {
      resettingForModeChange = true;
    }
  }

  if (resettingForModeChange) {
    // Can only write to up to 3 DAC lines without exceeding the loop time.
    // For now, all commands touch the same number of DAC lines.
    Application::updatePiezoZVoltage(0);
    Application::updateBiasVoltage(0);
  } else {

  }

  Application::updateCurrent();

  // Send data to the real-time monitor.
  if (ErrorMessage::hasError()) {
    return;
  }
  uint32_t iterationsPerLog = Log::targetLogPeriod / KilohertzLoop::period;
  if (KilohertzLoop::iterationID % iterationsPerLog == 0) {
    uint32_t ringIndex = Log::unsafeBufferedLogID % Log::logSize;

    Log::ringBuffers[0][ringIndex] = Application::state.filteredCurrent;
    Log::ringBuffers[1][ringIndex] = Application::state.piezoXVoltage;
    Log::ringBuffers[2][ringIndex] = Application::state.piezoYVoltage;
    Log::ringBuffers[3][ringIndex] = Application::state.piezoZVoltage;

    Log::unsafeBufferedLogID += 1;
  }
}