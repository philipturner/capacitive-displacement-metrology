#include "Application/Application.h"
#include "Application/ModeChanger.h"
#include "Command/Parsing/CommandTracker.h"
#include "Command/Tilt/Settings.h"
#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
#include "Util/Interpolate.h"
#include "Util/WaveUtil.h"
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
  if (KilohertzLoop::iterationID == modeChanger.transitionEnd) {
    
  } else if (KilohertzLoop::iterationID > modeChanger.transitionEnd) {
    Command command;
    if (CommandTracker::nextCommand(command)) {
      if (!command.isValid) {
        // Forward input error.
      } else if (command.mode == Command::Mode::imagingSettings) {
        Imager::updatePendingSettings(command);
      } else if (command.mode == Command::Mode::creepSettings) {
        Creep::Settings::update(command);
        Creep::Settings::forward();
      } else if (command.mode == Command::Mode::tiltSettings) {
        Tilt::Settings::update(command);
        Tilt::Settings::forward();
      } else {
        
      }
    } else if (TipApproacher::modeShouldChange()) {
      TipApproacher::forceModeChange();
    }
  }

  bool useADC = true;
  if (KilohertzLoop::iterationID < modeChangeEnd) {
    
  } else {
    if (Application::mode == Command::Mode::dacTest) {
      Application::dacTester.update();
    }
    if (Application::mode == Command::Mode::capacitanceReporting) {
      Application::updateCapacitanceTracker(/*regenerate=*/true);
    }
    if (Application::mode == Command::Mode::blindStepping) {
      Application::blindStepper.update();
    }
    if (Application::mode == Command::Mode::tipApproach) {
      Application::tipApproacher.update();
    }
    if (Application::mode == Command::Mode::idleFeedback) {
      Application::setBiasForFeedback();
      Application::correctZVoltage();
    }
    if (Application::mode == Command::Mode::spectroscopy) {
      Application::spectroscopy.update();
    }
    if (Application::mode == Command::Mode::simpleScanning) {
      Application::simpleScanner.update();      
    }
    if (Application::mode == Command::Mode::imaging) {
      Application::imager.update();
    }
    if (Application::mode == Command::Mode::tilt) {
      Application::tiltCalculator.update();
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
      Application::logNormalMessage();
    }
  }

  float2 stimulus;
  stimulus.x = Application::state.piezoXVoltage;
  stimulus.y = Application::state.piezoYVoltage;
  Application::creepFilter.update(stimulus);
}