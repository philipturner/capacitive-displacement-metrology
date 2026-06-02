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
uint32_t capacitanceUpdateCountAtModeChange = 0;

void kilohertzLoop() {
  if (resettingForModeChange) {
    resettingForModeChange = false;
    capacitanceUpdateCountAtModeChange = Application::state.capacitanceUpdateCount;

    // Update application
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
    if (Application::mode == Command::Mode::simpleScanning) {
      // TODO
    }

    // Forward necessary data to host program
    if (Application::mode == Command::Mode::imaging) {
      float X2 = 0;
      float Y2 = 0;
      if (nextCommand.alphaCode == 'd') {
        X2 = float(nextCommand.attributes[4]);
        Y2 = float(nextCommand.attributes[5]);
      }

      Log::writeValuesWithFlags(
        /*flags=*/4,
        float(nextCommand.alphaCode),
        float(nextCommand.attributes[0]),
        float(nextCommand.attributes[1]),
        float(nextCommand.attributes[2]),
        float(nextCommand.attributes[3]));
      
      Log::writeValuesWithFlags(
        /*flags=*/4,
        X2,
        Y2);
    }
    Log::writeValuesWithFlags(
      /*flags=*/1,
      float(Application::mode));
  } else {
    if (CommandTracker::nextCommand(nextCommand)) {
      resettingForModeChange = true;
    }
  }

  if (resettingForModeChange) {
    // Can only write to 3 DAC channels without exceeding the loop time.
    if (Application::mode == Command::Mode::dacTest) {
      uint32_t channelID = Application::dacTester.channelID;
      if (channelID != 4) {
        Application::updatePiezoVoltage(channelID, 0);
      }
    }

    if (Application::mode == Command::Mode::simpleScanning) {
      Application::updatePiezoVoltage(1, 0);
      Application::updatePiezoVoltage(2, 0);
    }

    Application::updateBiasVoltage(Feedback::setpointVoltage);
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
      Application::updateBiasVoltage(Feedback::setpointVoltage);
      Feedback::updatePiezoZ();
    }
    if (Application::mode == Command::Mode::spectroscopy) {
      Application::spectroscopy.update();
    }
    if (Application::mode == Command::Mode::simpleScanning) {
      // TODO
    }
    if (Application::mode == Command::Mode::imaging) {
      Application::updateBiasVoltage(Feedback::setpointVoltage);
      Feedback::updatePiezoZ();
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
    Application::logNormalMessage(capacitanceUpdateCountAtModeChange);
  }
}