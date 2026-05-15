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
uint32_t scanWavePeriod = 0;

float current = 0; // units: A
float filteredCurrent = 0; // units: A
float biasVoltage = 0; // units: V
float capacitance = 0; // units: F
float phaseShift = 0; // units: °

float fineXVoltage = 0; // units: V
float fineYVoltage = 0; // units: V
float filteredFineXVoltage = 0; // units: V
float filteredFineYVoltage = 0; // units: V

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
      char digit = Serial.available();
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

    scanWavePeriod = period;

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
CapacitanceTracker capTracker;
bool resetBias = false;
bool resetFineX = false;
bool resetFineY = false;

void updateMode() {
  resetBias = false;
  resetFineX = false;
  resetFineY = false;

  if (mode != latestInputMode) {
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
  }
  mode = latestInputMode;
}

float getScanVoltage() {
  uint32_t trueTime = micros();
  uint32_t phase = trueTime % scanWavePeriod;

  float phaseNormalized = float(phase) / float(scanWavePeriod);
  float amplitude = FilterUtil::sineWave(phaseNormalized);
  return amplitude;
}

void kilohertzLoop() {
  updateMode();
  if (mode == Mode::capacitance) {
    capTracker.update(capacitance, phaseShift);

    auto state = capTracker.getCurrentState();
    if (state == CapacitanceTracker::State::finished) {
      capTracker = CapacitanceTracker(true);
    }
  }

  // MARK: - Bias Voltage

  if (mode == Mode::riseTime) {
    uint32_t wavePeriodMicros = 1000;
    uint32_t trueTime = micros(); // doesn't have to be aligned to a start
    uint32_t phase = trueTime % wavePeriodMicros;

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
    float alpha = FilterUtil::getLowpassAlpha(1542, loopPeriod);
    filteredFineXVoltage *= 1 - alpha;
    filteredFineXVoltage += alpha * fineXVoltage;
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
    float alpha = FilterUtil::getLowpassAlpha(1542, loopPeriod);
    filteredFineYVoltage *= 1 - alpha;
    filteredFineYVoltage += alpha * fineYVoltage;
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
      // Alternative setup: fineX, filteredX, fineY, filteredY
      Log::ringBuffers[0][ringIndex] = filteredCurrent / 1e-12;
      Log::ringBuffers[1][ringIndex] = biasVoltage;

      if (mode == Mode::scanX) {
        Log::ringBuffers[2][ringIndex] = fineXVoltage;
        Log::ringBuffers[3][ringIndex] = filteredFineXVoltage;
      } else if (mode == Mode::scanY) {
        Log::ringBuffers[2][ringIndex] = fineYVoltage;
        Log::ringBuffers[3][ringIndex] = filteredFineYVoltage;
      }
    } else {
      Log::ringBuffers[0][ringIndex] = filteredCurrent / 1e-12;
      Log::ringBuffers[1][ringIndex] = biasVoltage;
      Log::ringBuffers[2][ringIndex] = capacitance / 1e-15;

      if (mode == Mode::capacitance) {
        // Use phase shift to show the state of the tracker.
        auto state = capTracker.getCurrentState();
        if (state == CapacitanceTracker::State::waiting) {
          Log::ringBuffers[3][ringIndex] = phaseShift;
        } else if (state == CapacitanceTracker::State::measuring) {
          Log::ringBuffers[3][ringIndex] = 0;
        } else {
          Serial.println("This should never happen.");
          exit(0);
        }
      } else {
        Log::ringBuffers[3][ringIndex] = phaseShift;
      }
    }

    Log::unsafeBufferedLogID += 1;
  }
}