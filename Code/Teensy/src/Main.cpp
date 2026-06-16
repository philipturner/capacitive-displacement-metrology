#include "Application/Application.h"
#include "Command/Parsing/CommandTracker.h"
#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
#include "Filter/Feedback.h"
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

Command nextCommand;
uint32_t modeChangeStart = 0;
uint32_t modeChangeEnd = 0;
bool modeChangeContinuesFeedback = false;
bool modeChangeRetractsZ = false;
float2 previousScannerVoltage;

void kilohertzLoop() {
  if (KilohertzLoop::iterationID == modeChangeEnd) {
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
      Application::tipApproacher = TipApproacher(
        TipApproacher::State::waitBeforeApproach, false);
    }
    if (Application::mode == Command::Mode::spectroscopy) {
      Application::spectroscopy = Spectroscopy(nextCommand);
    }
    if (Application::mode == Command::Mode::simpleScanning) {
      Application::simpleScanner = SimpleScanner(nextCommand);
    }
    if (Application::mode == Command::Mode::imaging) {
      Application::imager = Imager(nextCommand);
      Application::imager.forwardSettings();
    }

    Log::writeValuesWithFlags(1, float(Application::mode));
  } else if (KilohertzLoop::iterationID > modeChangeEnd) {
    if (CommandTracker::nextCommand(nextCommand)) {
      if (nextCommand.mode == Command::Mode::imagingSettings) {
        Imager::updatePendingSettings(nextCommand);
      } else if (nextCommand.mode == Command::Mode::creepSettings) {
        Application::creepFilter.updateSettings(nextCommand);
        Application::creepFilter.forwardState();
      } else {
        modeChangeStart = KilohertzLoop::iterationID;
        modeChangeEnd = modeChangeStart;
        modeChangeEnd += Imager::largeMoveRiseTime / KilohertzLoop::period;

        modeChangeContinuesFeedback = false;
        modeChangeRetractsZ = false;
        previousScannerVoltage.x = Application::state.piezoXVoltage;
        previousScannerVoltage.y = Application::state.piezoYVoltage;

        if (nextCommand.mode >= Command::Mode::idleFeedback) {
          modeChangeContinuesFeedback = true;
        } else if (nextCommand.mode >= Command::Mode::blindStepping) {
          modeChangeRetractsZ = true;
        }
      }
    } else {
      if (uint8_t(Application::mode) >= uint8_t(Command::Mode::idleFeedback)) {
        auto restorationState = TipApproacher::rangeRestorationState();
        if (restorationState != TipApproacher::State::feedback) {
          Application::mode = Command::Mode::tipApproach;
          Application::state.modeStartIterationID = KilohertzLoop::iterationID;
          Application::state.capacitanceUpdateCount = 0;

          Application::tipApproacher = TipApproacher(restorationState, true);

          Log::writeValuesWithFlags(
            1, // flags
            float(Command::Mode::tipApproach),
            float(1));
        }
      }
    }
  }

  bool useADC = true;
  if (KilohertzLoop::iterationID < modeChangeEnd) {
    if (modeChangeContinuesFeedback) {
      uint32_t feedbackStart = modeChangeStart + 500 / KilohertzLoop::period;
      if (KilohertzLoop::iterationID < feedbackStart) {
        Application::updateBiasVoltage(Feedback::setpointVoltage);
      } else {
        float deltaIters = KilohertzLoop::iterationID - feedbackStart;
        float deltaItersMax = (modeChangeEnd - feedbackStart) - 1;
        
        float progress = float(deltaIters) / float(deltaItersMax);
        progress = WaveUtil::thirdOrderSmoothstep(progress);

        float2 scannerVoltage = previousScannerVoltage * (1 - progress);
        Application::updatePiezoVoltage(1, scannerVoltage.x);
        Application::updatePiezoVoltage(2, scannerVoltage.y);
        Application::updatePiezoVoltage(3, Feedback::getVoltage());
      }
    } else if (modeChangeRetractsZ) {
      uint32_t turningPointIter = modeChangeStart + 600 / KilohertzLoop::period;
      if (KilohertzLoop::iterationID < turningPointIter) {
        float currentVoltage = Application::state.piezoZVoltage;
        if (currentVoltage > -270) {
          float dV = -1.4 * float(KilohertzLoop::period);

          float newVoltage = max(currentVoltage + dV, -270);
          Application::updatePiezoVoltage(3, newVoltage);
        }
      } else if (KilohertzLoop::iterationID == turningPointIter) {
        Application::updatePiezoVoltage(3, -270);
        
        useADC = false;
      }
    } else {
      Application::updateBiasVoltage(0);
      Application::updatePiezoVoltage(1, 0);
      Application::updatePiezoVoltage(2, 0);
      Application::updatePiezoVoltage(3, 0);

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
      Application::updateBiasVoltage(Feedback::setpointVoltage);
      Application::updatePiezoVoltage(3, Feedback::getVoltage());
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