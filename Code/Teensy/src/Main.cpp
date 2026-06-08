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
  KilohertzLoop::initialize(kilohertzLoop);
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
bool modeChangeNeedsFeedback = false;
bool modeChangeNeedsFixedZ = false;
float previousXYVoltage[2] = { 0, 0 };

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
      uint8_t modeCode = uint8_t(nextCommand.mode);

      if (modeCode < uint8_t(Command::Mode::placeholder1)) {
        modeChangeStart = KilohertzLoop::iterationID;
        modeChangeEnd = modeChangeStart;
        modeChangeEnd += Imager::largeMoveRiseTime / KilohertzLoop::period;

        modeChangeNeedsFeedback = false;
        modeChangeNeedsFixedZ = false;
        previousXYVoltage[0] = Application::state.piezoXVoltage;
        previousXYVoltage[1] = Application::state.piezoYVoltage;

        if (nextCommand.mode >= Command::Mode::idleFeedback) {
          modeChangeNeedsFeedback = true;
        } else if (nextCommand.mode >= Command::Mode::blindStepping) {
          modeChangeNeedsFixedZ = true;
        }
      } else if (modeCode == uint8_t(Command::Mode::imagingSettings)) {

      } else {
        ErrorMessage::reset();
        ErrorMessage::errorType = ErrorMessage::Type::fatal;

        ErrorMessage::addString("Invalid mode.");
        ErrorMessage::addNewline();
        ErrorMessage::addInteger(modeCode);
        ErrorMessage::addNewline();
        return;
      }
    }
  }

  bool useADC = true;
  if (KilohertzLoop::iterationID < modeChangeEnd) {
    if (modeChangeNeedsFeedback) {
      uint32_t feedbackStart = modeChangeStart + 500 / KilohertzLoop::period;
      if (KilohertzLoop::iterationID < feedbackStart) {
        Application::updateBiasVoltage(Feedback::setpointVoltage);
      } else {
        float deltaIters = KilohertzLoop::iterationID - feedbackStart;
        float deltaItersMax = (modeChangeEnd - feedbackStart) - 1;
        
        float progress = float(deltaIters) / float(deltaItersMax);
        progress = FilterUtil::thirdOrderSmoothstep(progress);
        progress = 1 - progress;

        float piezoXVoltage = previousXYVoltage[0] * progress;
        float piezoYVoltage = previousXYVoltage[1] * progress;
        Application::updatePiezoVoltage(1, piezoXVoltage);
        Application::updatePiezoVoltage(2, piezoYVoltage);
        Feedback::updatePiezoZ(false);
      }
    } else {
      Application::updateBiasVoltage(0);
      Application::updatePiezoVoltage(1, 0);
      Application::updatePiezoVoltage(2, 0);
      if (!modeChangeNeedsFixedZ) {
        Application::updatePiezoVoltage(3, 0);
      }

      useADC = false;
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
    if (Application::mode == Command::Mode::idleFeedback) {
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

  Application::state.updateCurrent(useADC);

  // Send data to the real-time monitor.
  if (ErrorMessage::hasError()) {
    return;
  }
  uint32_t iterationsPerLog = Log::logPeriod / KilohertzLoop::period;
  if (KilohertzLoop::iterationID % iterationsPerLog == 0) {
    Application::logNormalMessage();
  }
}