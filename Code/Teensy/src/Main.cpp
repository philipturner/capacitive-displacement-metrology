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

float lowpassFilteredCurrent = 0;
float biasVoltage = 0;
float capacitance = 0;
float phaseShift = 0;

enum class Mode {
  noise = 0,
  riseTime = 1,
  capacitance = 2,
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

void updateMode() {
  Mode nextMode = latestInputMode;
  if (mode != nextMode) {
    if (nextMode == Mode::capacitance) {
      capTracker = CapacitanceTracker(true);
    }
  }
  mode = nextMode;
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

  if (mode == Mode::noise) {
    biasVoltage = 0;
  } else if (mode == Mode::riseTime) {
    uint32_t wavePeriodMicros = 1000;
    uint32_t trueTime = micros(); // doesn't have to be aligned to a start
    uint32_t phase = trueTime % wavePeriodMicros;

    float phaseNormalized = float(phase) / float(wavePeriodMicros);
    float amplitude = FilterUtil::triangleWave(phaseNormalized);
    biasVoltage = 10 * amplitude;
  } else if (mode == Mode::capacitance) {
    biasVoltage = capTracker.getBiasVoltage();
  }
  DAC2::writeVoltage(0, biasVoltage);

  {
    auto conversion = ADC::readVoltage();
    float current = -conversion.voltage / 1e9;
    float alpha = FilterUtil::getLowpassAlpha(10000, loopPeriod);
    lowpassFilteredCurrent *= 1 - alpha;
    lowpassFilteredCurrent += alpha * current;

    if (mode == Mode::capacitance) {
      float current = lowpassFilteredCurrent;
      float sineMixed = referenceSine * current;
      float cosineMixed = referenceCosine * current;
      sineSquaredAccumulator += sineMixed * sineMixed;
      cosineSquaredAccumulator += cosineMixed * cosineMixed;
      rmsCurrentSampleCount += 1;

      if (previousFilteredCurrent < 0 && lowpassFilteredCurrent > 0) {
        if (zeroCrossingIterationID == -1) {
          zeroCrossingIterationID = KilohertzLoop::iterationID;
        }
      }
    }
  }
  
  uint32_t iterationsPerLog = Log::targetLogPeriod / loopPeriod;
  if (KilohertzLoop::iterationID % iterationsPerLog == 0) {
    uint32_t ringIndex = Log::unsafeBufferedLogID % Log::logSize;
    Log::ringBuffers[0][ringIndex] = lowpassFilteredCurrent / 1e-12;
    Log::ringBuffers[1][ringIndex] = biasVoltage;
    Log::ringBuffers[2][ringIndex] = capacitance / 1e-15;

    // Use phase shift to show the state of the tracker.
    //        -90 = waiting
    //          0 = measuring
    // true phase = finished
    //
    // Change the host PC code to trigger on phase shift crossing -45.
    Log::ringBuffers[3][ringIndex] = phaseShift;

    Log::unsafeBufferedLogID += 1;
  }
}