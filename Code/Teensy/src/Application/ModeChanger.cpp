#include "ModeChanger.h"

#include "Application/Application.h"
#include "Diagnostics/Log.h"
#include "IC/DAC.h"
#include "Util/Interpolate.h"
#include "Util/WaveUtil.h"

void ModeChanger::start(Command command) {
  this->command = command;

  startIteration = KilohertzLoop::iterationID;
  endIteration = startIteration;
  endIteration += Imager::largeMoveRiseTime / KilohertzLoop::period;

  continueFeedback = false;
  retractZ = false;
  if (command.mode >= Command::Mode::idleFeedback) {
    continueFeedback = true;
  } else if (command.mode >= Command::Mode::blindStepping) {
    retractZ = true;
  }

  previousScannerVoltage.x = Application::state.piezoXVoltage;
  previousScannerVoltage.y = Application::state.piezoYVoltage;
  if (command.mode == Command::Mode::tiltCalculation) {
    targetScannerVoltage = Tilt::Calculator::getOriginScannerVoltage(command);
  } else {
    targetScannerVoltage = float2(0);
  }
}

void ModeChanger::update(bool &useADC) const {
  if (continueFeedback) {
    uint32_t feedbackStart = startIteration + 500 / KilohertzLoop::period;
    if (KilohertzLoop::iterationID < feedbackStart) {
      Application::setBiasForFeedback();
    } else {
      float deltaIters = KilohertzLoop::iterationID - feedbackStart;
      float deltaItersMax = (endIteration - feedbackStart) - 1;
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
  } else if (retractZ) {
    uint32_t turningPoint = startIteration + 600 / KilohertzLoop::period;
    if (KilohertzLoop::iterationID < turningPoint) {
      float currentVoltage = Application::state.piezoZVoltage;
      if (currentVoltage > -270) {
        float dV = -1.4 * float(KilohertzLoop::period);
        float newVoltage = max(currentVoltage + dV, -270);
        Application::updatePiezoVoltage(3, newVoltage);
      }
    } else if (KilohertzLoop::iterationID == turningPoint) {
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

void modeChangeCommon(Command::Mode mode) {
  Application::mode = mode;
  Application::state.modeStartIterationID = KilohertzLoop::iterationID;
  Application::state.capacitanceUpdateCount = 0;
  Application::creepFilter.futureAccumulatedDrift = float2(0);
}

void ModeChanger::end() const {
  modeChangeCommon(command.mode);

  switch (Application::mode) {
    case Command::Mode::dacTest:
      Application::dacTester = DACTester(command);
      break;
    case Command::Mode::capacitanceReporting:
      Application::capTracker = CapacitanceTracker(true);
      break;
    case Command::Mode::blindStepping:
      Application::blindStepper = BlindStepper(command);
      break;
    case Command::Mode::tipApproach:
      auto state = TipApproacher::State::waitBeforeApproach;
      Application::tipApproacher = TipApproacher(state, false);
      break;
    case Command::Mode::spectroscopy:
      Application::spectroscopy = Spectroscopy(command);
      break;
    case Command::Mode::simpleScanning:
      Application::simpleScanner = SimpleScanner(command);
      break;
    case Command::Mode::imaging:
      Application::imager = Imager(command);
      Application::imager.forwardSettings();
      break;
    case Command::Mode::tiltCalculation:
      Application::tiltCalculator = Tilt::Calculator(command);
      break;
    default:
      break;
  }

  Log::writeValuesWithFlags(
    1, // flags
    float(Application::mode));
}

void ModeChanger::forceModeChange() const {
  modeChangeCommon(Command::Mode::tipApproach);

  auto state = TipApproacher::rangeRestorationState();
  Application::tipApproacher = TipApproacher(state, true);

  Log::writeValuesWithFlags(
    1, // flags
    float(Command::Mode::tipApproach),
    float(1));
}