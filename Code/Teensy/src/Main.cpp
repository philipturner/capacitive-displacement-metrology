#include "Diagnostics/Log.h"
#include "Diagnostics/CapacitanceTracker.h"
#include "IC/ADC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Time/KilohertzLoop.h"
#include "Util/Application.h"
#include "Util/FilterUtil.h"

// MARK: - Global Variables

constexpr uint32_t loopPeriod = 12;

float current = 0; // units: A
float filteredCurrent = 0; // units: A
float biasVoltage = 0; // units: V
float capacitance = 0; // units: F
float phaseShift = 0; // units: °

float fineXVoltage = 0; // units: V
float fineYVoltage = 0; // units: V

enum class Mode {
  noise = 0,
  riseTime = 1,
  capacitance = 2,
  scanX = 3,
  scanY = 4,
};
Mode getDefaultMode() {
  return Mode::riseTime;
}
Mode latestInputMode = getDefaultMode();
uint32_t latestScanWavePeriod = 0;

// MARK: - Setup and Loop

void kilohertzLoop();

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Log::initialize();
  KilohertzLoop::initialize(kilohertzLoop, loopPeriod);
}

void processInput() {
  char incomingByte = Serial.read();

  if (incomingByte == 'n') {
    latestInputMode = Mode::noise;
  } else if (incomingByte == 'r') {
    latestInputMode = Mode::riseTime;
  } else if (incomingByte == 'c') {
    latestInputMode = Mode::capacitance;
  } else if (incomingByte == 'x' || incomingByte == 'y') {
    // decode the text into a period (in microseconds)
    uint32_t period = 0;
    while (Serial.available() > 0) {
      char digit = Serial.read();
      if (digit >= '0' && digit <= '9') {
        uint32_t numberValue = uint32_t(digit - '0');
        period = period * 10 + numberValue;
      } else {
        // Handle accidental key presses gracefully.
        break;
      }
    }
    if (period == 0 || (period % loopPeriod != 0)) {
      Serial.print("Invalid period: ");
      Serial.print(period);
      Serial.println();
      exit(0);
    }

    // prevent undefined behavior while the scan wave period is written
    latestInputMode = Mode::noise;

    latestScanWavePeriod = period;

    // safe to write the mode *after* the scan wave period is written
    if (incomingByte == 'x') {
      latestInputMode = Mode::scanX;
    } else if (incomingByte == 'y') {
      latestInputMode = Mode::scanY;
    }
  }
}

void loop() {
  delay(50);

  if (KilohertzLoop::errorCode != 0) {
    Serial.print("KilohertzLoop failed with error code: ");
    Serial.print(KilohertzLoop::errorCode);
    Serial.println();
  } else if (Log::errorCode != 0) {
    Serial.print("Log failed with error code: ");
    Serial.print(Log::errorCode);
    Serial.println();
  } else {
    Log::transmitBufferedSamples();
  }

  if (Serial.available() > 0) {
    processInput();

    // Prevent accidents from multiple key presses.
    while (Serial.available() > 0) {
      Serial.read();
    }
  }
}

// MARK: - Kilohertz Loop

Mode mode = getDefaultMode();
uint32_t scanWavePeriod = 0;

CapacitanceTracker capTracker;
bool resetBias = false;
bool resetFineX = false;
bool resetFineY = false;

uint32_t scanStartIterID;
uint32_t zeroCrossingStartID;
float zeroCrossingIterations;
float zeroCrossingPreviousValue = 0;

bool getModeDidChange() {
  if (mode != latestInputMode) {
    return true;
  }
  if (mode == Mode::scanX || mode == Mode::scanY) {
    if (scanWavePeriod != latestScanWavePeriod) {
      return true;
    }
  }
  return false;
}

void updateMode() {
  resetBias = false;
  resetFineX = false;
  resetFineY = false;

  if (getModeDidChange()) {
    // Cleanup operations for previous mode.
    if (mode == Mode::noise) {
      
    } else if (mode == Mode::riseTime) {
      resetBias = true;
    } else if (mode == Mode::capacitance) {
      resetBias = true;
    } else if (mode == Mode::scanX) {
      resetFineX = true;
    } else if (mode == Mode::scanY) {
      resetFineY = true;
    }

    // Setup operations for current mode.
    if (latestInputMode == Mode::capacitance) {
      capTracker = CapacitanceTracker(true);
    }
    if (latestInputMode == Mode::scanX ||
        latestInputMode == Mode::scanY) {
      scanStartIterID = KilohertzLoop::iterationID;
      zeroCrossingStartID = KilohertzLoop::iterationID;
      zeroCrossingIterations = -2;
    }
  }

  // It should be safe to copy the state over in this way, because nothing
  // interrupts the interrupt routine.
  mode = latestInputMode;
  scanWavePeriod = latestScanWavePeriod;
}

float getScanVoltage() {
  uint32_t deltaIters = KilohertzLoop::iterationID - scanStartIterID;
  uint32_t deltaMicros = deltaIters * KilohertzLoop::period;
  uint32_t phase = deltaMicros % scanWavePeriod;

  float phaseNormalized = float(phase) / float(scanWavePeriod);
  float amplitude = FilterUtil::sineWave(phaseNormalized);
  return 50 * amplitude;
}

void trackZeroCrossing(float value) {
  float previousValue = zeroCrossingPreviousValue;
  if (previousValue < 0 && value > 0) {
    if (zeroCrossingIterations == -2) {
      uint32_t iterationID = KilohertzLoop::iterationID;
      zeroCrossingIterations = float(iterationID - zeroCrossingStartID);

      float progress = (0 - previousValue) / (value - previousValue);
      float correction = -1 * (1 - progress) + 0 * progress;
      zeroCrossingIterations += correction;
    }
  }

  zeroCrossingPreviousValue = value;
}

void kilohertzLoop() {
  updateMode();
  if (mode == Mode::capacitance) {
    capTracker.update(capacitance, phaseShift);

    auto state = capTracker.getCurrentState();
    if (state == CapacitanceTracker::State::finished) {
      capTracker = CapacitanceTracker(true);
      capTracker.update(capacitance, phaseShift);
    }
  }
  if (mode == Mode::scanX || mode == Mode::scanY) {
    uint32_t itersPerWave = scanWavePeriod / KilohertzLoop::period;
    uint32_t nextStartID = zeroCrossingStartID + itersPerWave;
    if (KilohertzLoop::iterationID == nextStartID) {
      if (zeroCrossingIterations == -2) {
        scanFilterTimeLag = 0;
      } else {
        scanFilterTimeLag = zeroCrossingIterations;
        scanFilterTimeLag *= float(KilohertzLoop::period);
      }

      zeroCrossingStartID = nextStartID;
      zeroCrossingIterations = -2;
    } else if (KilohertzLoop::iterationID > nextStartID) {
      Serial.println("Unexpected behavior:");
      Serial.println(KilohertzLoop::iterationID);
      Serial.println(nextStartID);
      exit(0);
    }
  }

  // MARK: - Bias Voltage

  if (mode == Mode::riseTime) {
    uint32_t wavePeriodMicros = 1008;

    uint32_t deltaIters = KilohertzLoop::iterationID;
    uint32_t deltaMicros = deltaIters * KilohertzLoop::period;
    uint32_t phase = deltaMicros % wavePeriodMicros;

    float phaseNormalized = float(phase) / float(wavePeriodMicros);
    float amplitude = FilterUtil::triangleWave(phaseNormalized);
    biasVoltage = 10 * amplitude;
  } else if (mode == Mode::capacitance) {
    biasVoltage = capTracker.getBiasVoltage();
  } else if (resetBias) {
    biasVoltage = 0;
  }
  DAC2::writeVoltage(0, biasVoltage);

  // MARK: - Fine X Voltage

  if (mode == Mode::scanX) {
    fineXVoltage = getScanVoltage();
    PA95::writeVoltage(1, fineXVoltage);
  } else if (resetFineX) {
    fineXVoltage = 0;
    PA95::writeVoltage(1, fineXVoltage);
  }

  {
    float alpha = FilterUtil::getLowpassAlpha(1500, loopPeriod);
    filteredFineXVoltage *= 1 - alpha;
    filteredFineXVoltage += alpha * fineXVoltage;
    if (mode == Mode::scanX) {
      trackZeroCrossing(filteredFineXVoltage);
    }
  }

  // MARK: - Fine Y Voltage

  if (mode == Mode::scanY) {
    fineYVoltage = getScanVoltage();
    PA95::writeVoltage(2, fineYVoltage);
  } else if (resetFineY) {
    fineYVoltage = 0;
    PA95::writeVoltage(2, fineYVoltage);
  }

  {
    float alpha = FilterUtil::getLowpassAlpha(1500, loopPeriod);
    filteredFineYVoltage *= 1 - alpha;
    filteredFineYVoltage += alpha * fineYVoltage;
    if (mode == Mode::scanY) {
      trackZeroCrossing(filteredFineYVoltage);
    }
  }
  
  // MARK: - Current
  
  {
    auto conversion = ADC::readVoltage();
    current = -conversion.voltage / 1e9;

    float alpha = FilterUtil::getLowpassAlpha(10000, loopPeriod);
    filteredCurrent *= 1 - alpha;
    filteredCurrent += alpha * current;

    if (mode == Mode::capacitance) {
      capTracker.integrate(filteredCurrent);
    }
  }

  uint32_t iterationsPerLog = Log::targetLogPeriod / loopPeriod;
  if (KilohertzLoop::iterationID % iterationsPerLog == 0) {
    uint32_t ringIndex = Log::unsafeBufferedLogID % Log::logSize;

    if (mode == Mode::scanX || mode == Mode::scanY) {
      Log::ringBuffers[0][ringIndex] = filteredCurrent / 1e-12;

      if (mode == Mode::scanX) {
        Log::ringBuffers[1][ringIndex] = fineXVoltage;
        Log::ringBuffers[2][ringIndex] = filteredFineXVoltage;
      } else if (mode == Mode::scanY) {
        Log::ringBuffers[1][ringIndex] = fineYVoltage;
        Log::ringBuffers[2][ringIndex] = filteredFineYVoltage;
      }

      Log::ringBuffers[3][ringIndex] = scanFilterTimeLag;
    } else {
      Log::ringBuffers[0][ringIndex] = filteredCurrent / 1e-12;
      Log::ringBuffers[1][ringIndex] = biasVoltage;
      Log::ringBuffers[2][ringIndex] = capacitance / 1e-15;
      Log::ringBuffers[3][ringIndex] = phaseShift;
    }

    Log::unsafeBufferedLogID += 1;
  }
}