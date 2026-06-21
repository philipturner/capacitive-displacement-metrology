#include "Application/Application.h"
#include "Application/ModeChanger.h"
#include "Command/Parsing/CommandTracker.h"
#include "Command/Tilt/Settings.h"
#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
#include "Filter/Creep/Settings.h"
#include "Time/KilohertzLoop.h"
#include <Arduino.h>

#include "Time/Profiling.h"

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
    uint32_t time0 = ARM_DWT_CYCCNT;
    modeChanger.end();
    uint32_t time1 = ARM_DWT_CYCCNT;

    Serial.print("modeChanger.end() ");
    Profiling::display(time0, time1);
    Serial.println();
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
        uint32_t time5 = ARM_DWT_CYCCNT;
        modeChanger.start(command);
        uint32_t time6 = ARM_DWT_CYCCNT;

        Serial.print("modeChanger.start() ");
        Profiling::display(time5, time6);
        Serial.println();
      }
    } else if (TipApproacher::modeShouldChange()) {
      ModeChanger::forceModeChange();
    }
  }

  bool useADC = true;
  if (KilohertzLoop::iterationID < modeChanger.endIteration) {
    uint32_t time5 = ARM_DWT_CYCCNT;
    modeChanger.update(useADC);
    uint32_t time6 = ARM_DWT_CYCCNT;

    if (KilohertzLoop::iterationID % 25 == 0 || KilohertzLoop::iterationID == modeChanger.startIteration) {
        Serial.print("modeChanger.update() ");
        Profiling::display(time5, time6);
        Serial.print(KilohertzLoop::iterationID - modeChanger.startIteration);
        Serial.println();
    }
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

  uint32_t time7 = ARM_DWT_CYCCNT;

  Application::state.updateCurrent(useADC);
  if (!useADC) {
    delayNanoseconds(700);
  }

  uint32_t time8 = ARM_DWT_CYCCNT;

  Application::updatePiezoZDeferred();

  uint32_t time9 = ARM_DWT_CYCCNT;

  // Send data to the real-time monitor.
  if (!ErrorMessage::hasError()) {
    uint32_t iterationsPerLog = Log::logPeriod / KilohertzLoop::period;
    if (KilohertzLoop::iterationID % iterationsPerLog == 0) {
      Application::logHistoryMessage();
    }
  }

  uint32_t time10 = ARM_DWT_CYCCNT;

  float2 stimulus;
  stimulus.x = Application::state.piezoXVoltage;
  stimulus.y = Application::state.piezoYVoltage;
  Application::creepFilter.update(stimulus);

  uint32_t time11 = ARM_DWT_CYCCNT;

  // if (KilohertzLoop::iterationID % 1997 == 0 && Application::mode == Command::Mode::imaging) {
  //   Serial.print("kilohertzLoop ");
  //   Profiling::display(time7, time8);
  //   Profiling::display(time8, time9);
  //   Profiling::display(time9, time10);
  //   Profiling::display(time10, time11);
  //   Serial.println();
  // }
}