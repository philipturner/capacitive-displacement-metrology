#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include "Util/Feedback.h"
#include "Util/FilterUtil.h"
#include <Arduino.h>

void kilohertzLoop();

void setup() {
  Application::initialize();
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

// Allocate one loop iteration of buffer time between command changes.
Command nextCommand;
bool resettingForModeChange = false;

void kilohertzLoop() {
  if (resettingForModeChange) {
    resettingForModeChange = false;

    Application::mode = nextCommand.mode;
    if (Application::mode == Command::Mode::dacTest) {
      Application::dacTester = DACTester(nextCommand);
    }
    if (Application::mode == Command::Mode::capacitanceReporting) {
      Application::capTracker = CapacitanceTracker(true);
    }
    if (Application::mode == Command::Mode::blindStepping) {
      Application::blindStepper = BlindStepper(nextCommand);
    }
    if (Application::mode == Command::Mode::tipApproach) {
      Application::tipApproacher = TipApproacher(true);
    }
    if (Application::mode == Command::Mode::spectroscopy) {
      Application::spectroscopy = Spectroscopy(nextCommand);
    }

    Log::writeValues(
      /*lane0=*/float(Application::mode),
      /*lane1=*/0,
      /*lane2=*/0,
      /*lane3=*/0,
      /*lane4=*/0,
      /*flags=*/0b01);
  } else {
    if (CommandTracker::nextCommand(nextCommand)) {
      resettingForModeChange = true;
    }
  }

  if (resettingForModeChange) {
    // Can only write to 3 DAC channels without exceeding the loop time.
    if (Application::mode == Command::Mode::dacTest) {
      if (Application::dacTester.channelID == 4) {
        Application::updateBiasVoltage(0);
      } else {
        Application::updatePiezoVoltage(
          Application::dacTester.channelID, 0);
      }
    } else {
      Application::updateBiasVoltage(Feedback::setpointVoltage);
    }
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
    if (Application::mode == Command::Mode::spectroscopy) {
      Application::spectroscopy.update();
    }
  }

  Application::state.updateCurrent();
  Application::state.updateCurrentSpike();

  // Send data to the real-time monitor.
  if (ErrorMessage::hasError()) {
    return;
  }
  uint32_t iterationsPerLog = Log::logPeriod / KilohertzLoop::period;
  if (KilohertzLoop::iterationID % iterationsPerLog == 0) {
    Application::logNormalMessage();
  }
}