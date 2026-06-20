#include "ModeChanger.h"

#include "Application/Application.h"
#include "Diagnostics/Log.h"
#include "IC/DAC.h"

void ModeChanger::start(Command command) {
  modeChangeStart = KilohertzLoop::iterationID;
  modeChangeEnd = modeChangeStart;
  modeChangeEnd += Imager::largeMoveRiseTime / KilohertzLoop::period;

  modeChangeContinuesFeedback = false;
  modeChangeRetractsZ = false;

  if (nextCommand.mode >= Command::Mode::idleFeedback) {
    modeChangeContinuesFeedback = true;
  } else if (nextCommand.mode >= Command::Mode::blindStepping) {
    modeChangeRetractsZ = true;
  }

  previousScannerVoltage.x = Application::state.piezoXVoltage;
  previousScannerVoltage.y = Application::state.piezoYVoltage;
  if (false) {
    // tiltCalculation, 'o' mode
  } else {
    targetScannerVoltage = float2(0);
  }
}

void ModeChanger::update(bool &useADC) const {
  if (modeChangeContinuesFeedback) {
    uint32_t feedbackStart = modeChangeStart + 500 / KilohertzLoop::period;
    if (KilohertzLoop::iterationID < feedbackStart) {
      Application::setBiasForFeedback();
    } else {
      float deltaIters = KilohertzLoop::iterationID - feedbackStart;
      float deltaItersMax = (modeChangeEnd - feedbackStart) - 1;
      
      float progress = float(deltaIters) / float(deltaItersMax);
      progress = WaveUtil::thirdOrderSmoothstep(progress);

      float2 scannerVoltage = interpolate(
        previousScannerVoltage, 
        targetScannerVoltage, 
        progress);
      
      Application::updatePiezoVoltage(1, scannerVoltage.x);
      DAC::enableSafeWait = false;
      Application::updatePiezoVoltage(2, scannerVoltage.y);
      DAC::enableSafeWait = true;
      Application::correctZVoltage();
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
    }
  } else {
    Application::updateBiasVoltage(0);
    Application::updatePiezoVoltage(1, 0);
    Application::updatePiezoVoltage(2, 0);
    Application::updatePiezoVoltage(3, 0);

    useADC = false;
  }
}

void ModeChanger::end() const {
  Application::mode = nextCommand.mode;
  Application::state.modeStartIterationID = KilohertzLoop::iterationID;
  Application::state.capacitanceUpdateCount = 0;
  Application::creepFilter.futureAccumulatedDrift = float2(0);

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
  if (Application::mode == Command::Mode::tilt) {
    Application::tiltCalculator = Tilt::Calculator(nextCommand);
  }

  Log::writeValuesWithFlags(1, float(Application::mode));
}