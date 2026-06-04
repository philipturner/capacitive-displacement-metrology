#include "Application/Application.h"
#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
#include "Util/Feedback.h"
#include "Util/FilterUtil.h"
#include <Arduino.h>

void kilohertzLoop();

void setup() {
  Application::initialize();
  Feedback::notchFilter = NotchFilter(12);
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

Command nextCommand;
uint32_t modeChangeStart = 0;
uint32_t modeChangeEnd = 0;

void kilohertzLoop() {
  if (KilohertzLoop::iterationID == modeChangeEnd) {
    // Update application
    Application::mode = nextCommand.mode;
    Application::state.modeStartIterationID = KilohertzLoop::iterationID;
    Application::state.capacitanceUpdateCount = 0;
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
      Application::simpleScanner = SimpleScanner(nextCommand);
    }
    if (Application::mode == Command::Mode::imaging) {
      Application::imager = Imager(nextCommand);
    }

    // Forward necessary data to host program
    if (Application::mode == Command::Mode::imaging) {
      Application::imager.forwardParameters();
    }
    Log::writeValuesWithFlags(
      /*flags=*/1,
      float(Application::mode));
  } else if (KilohertzLoop::iterationID > modeChangeEnd) {
    if (CommandTracker::nextCommand(nextCommand)) {
      modeChangeStart = KilohertzLoop::iterationID;
      modeChangeEnd = modeChangeStart;

      if (Application::mode >= Command::Mode::tipApproach &&
          nextCommand.mode >= Command::Mode::idleFeedback) {
        modeChangeEnd += Imager::largeMoveRiseTime / KilohertzLoop::period;
      } else {
        modeChangeEnd += 1;
      }
    }
  }

  if (KilohertzLoop::iterationID < modeChangeEnd) {
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
      uint32_t time = Application::state.getTimeSinceModeStart();
      if (time == 0) {
        Application::updateBiasVoltage(Feedback::setpointVoltage);
      }
      Feedback::updatePiezoZ();
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