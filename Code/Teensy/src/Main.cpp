#include "Application/Application.h"
#include "Application/ModeChanger.h"
#include "Command/Parsing/CommandTracker.h"
#include "Command/Tilt/Settings.h"
#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
#include "Filter/Creep/Settings.h"
#include "Time/KilohertzLoop.h"
#include <Arduino.h>

void kilohertzLoop();

void setup() {
  Application::initialize();
  KilohertzLoop::initialize(kilohertzLoop);
}

void loop() {
  delay(5);

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

ModeChanger modeChanger;

void kilohertzLoop() {
  if (KilohertzLoop::iterationID == modeChanger.endIteration) {
    modeChanger.end();
  } else if (KilohertzLoop::iterationID > modeChanger.endIteration) {
    Command command;
    if (CommandTracker::nextCommand(command)) {
      if (!command.isValid) {
        Log::write(Log::Flags::invalidCommand);
      } else if (command.mode == Command::Mode::imagingSettings) {
        Imager::updatePendingSettings(command);
      } else if (command.mode == Command::Mode::creepSettings) {
        Creep::Settings::update(command);
        Creep::Settings::forward();
      } else if (command.mode == Command::Mode::tiltSettings) {
        Tilt::Settings::update(command);
        Tilt::Settings::forward();
      } else {
        modeChanger.start(command);
      }
    } else if (TipApproacher::modeShouldChange()) {
      ModeChanger::forceModeChange();
    }
  }

  bool useADC = true;
  if (KilohertzLoop::iterationID < modeChanger.endIteration) {
    modeChanger.update(useADC);
  } else {
    switch (Application::mode) {
      case Command::Mode::idle:
        break;
      case Command::Mode::dacTest:
        Application::dacTester.update();
        break;
      case Command::Mode::capacitanceReporting:
        Application::updateCapacitanceTracker(/*regenerate=*/true);
        break;
      case Command::Mode::blindStepping:
        Application::blindStepper.update();
        break;
      case Command::Mode::tipApproach:
        Application::tipApproacher.update();
        break;
      case Command::Mode::idleFeedback:
        Application::correctZVoltage();
        break;
      case Command::Mode::spectroscopy:
        Application::spectroscopy.update();
        break;
      case Command::Mode::simpleScanning:
        Application::simpleScanner.update();
        break;
      case Command::Mode::imaging:
        Application::imager.update();
        break;
      case Command::Mode::tiltCalculation:
        Application::tiltCalculator.update();
        break;
      default:
        Serial.println("Unexpected mode.");
        exit(0);
        break;
    }
  }

  Application::state.previous = Application::state.abbreviated();
  Application::state.updateCurrent(useADC);
  if (!useADC) {
    delayNanoseconds(700);
  }
  Application::updatePiezoZDeferred();

  // Send data to the real-time monitor.
  if (!ErrorMessage::hasError()) {
    uint32_t iterationsPerLog = Log::logPeriod / KilohertzLoop::period;
    if (KilohertzLoop::iterationID % iterationsPerLog == 0) {
      Application::logHistoryMessage();
    }
  }

  float2 stimulus;
  stimulus.x = Application::state.piezoXVoltage;
  stimulus.y = Application::state.piezoYVoltage;
  Application::creepFilter.update(stimulus);
}