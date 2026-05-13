#include "IC/ADC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Time/KilohertzLoop.h"
#include "Time/Log.h"
#include "Util/Application.h"
#include "Util/FilterUtil.h"

// MARK: - Global Variables

constexpr uint32_t loopPeriod = 7;
constexpr uint32_t capacitanceWavePeriod = 700;
constexpr uint32_t capacitanceWaveCount = 2; // 4

float lowpassFilteredCurrent = 0;
float biasVoltage = 0;
float rmsCurrent = 0;
float capacitance = 0;

float rmsCurrentAccumulator = 0;
uint32_t rmsCurrentSampleCount = 0;

// TODO: Procedures for transitioning between modes in the fast loop.
// Copy the slow loop's mode to the fast loop's mode and detect changes
// that way, without data races.
//
// Also, there can be dedicated amounts of time for transitioning between
// modes in the fast loop, to let voltage spikes settle. But we don't
// need that for this demonstration.

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
uint32_t startIterationID = 0;
uint32_t startTrueTime = 0;

void updateMode() {
  Mode nextMode = latestInputMode;
  if (mode != nextMode) {
    startIterationID = KilohertzLoop::iterationID;
    startTrueTime = micros();
  }
  mode = nextMode;
}

void updateCapacitance() {
  uint32_t iterationsPerMeasurement = capacitanceWaveCount;
  iterationsPerMeasurement *= capacitanceWavePeriod / loopPeriod;

  uint32_t iterationDelta = KilohertzLoop::iterationID;
  iterationDelta -= startIterationID;

  if (iterationDelta % iterationsPerMeasurement == 0) {
    if (iterationDelta > 0) {
      if (rmsCurrentSampleCount != iterationsPerMeasurement / 2) {
        Serial.println("Unexpected behavior in capacitance measurement");
        Serial.println(rmsCurrentSampleCount);
        Serial.println(iterationsPerMeasurement);
        exit(0);
      }
    }

    rmsCurrentAccumulator = 0;
    rmsCurrentSampleCount = 0;
  }
}

void kilohertzLoop() {
  updateMode();
  if (mode == Mode::capacitance) {
    updateCapacitance();
  }

  if (mode == Mode::noise) {
    biasVoltage = 0;
  } else if (mode == Mode::riseTime) {
    uint32_t wavePeriodMicros = 1000;
    uint32_t elapsedTime = micros() - startTrueTime;
    uint32_t phase = elapsedTime % wavePeriodMicros;

    float phaseNormalized = float(phase) / float(wavePeriodMicros);
    float amplitude = FilterUtil::triangleWave(phaseNormalized);
    biasVoltage = 10 * amplitude;
  } else if (mode == Mode::capacitance) {

  }

  uint32_t elapsedTimeMicros = KilohertzLoop::iterationID * loopPeriod;
  uint32_t sinePeriodMicros = 1000;
  uint32_t phaseMicros = elapsedTimeMicros % sinePeriodMicros;

  if (mode == Mode::riseTime) {
    float phaseNormalized = float(phaseMicros) / float(sinePeriodMicros);
    float waveValueNormalized = FilterUtil::triangleWave(phaseNormalized);
    biasVoltage = 10 * waveValueNormalized;
  } else if (mode == Mode::noise) {
    biasVoltage = 0;
  }
  DAC2::writeVoltage(0, biasVoltage);

  if (KilohertzLoop::iterationID % 2 == 0)  {
    auto conversion = ADC::readVoltage();
    float tiaVoltage = conversion.voltage;

    constexpr float frequency = 10000;
    float alpha = FilterUtil::getLowpassAlpha(frequency, loopPeriod * 2);
    lowpassVoltage = alpha * tiaVoltage + (1 - alpha) * lowpassVoltage;
  }

  uint32_t iterationsPerLog = logPeriod / loopPeriod;
  if (KilohertzLoop::iterationID % iterationsPerLog == 0) {
    uint32_t ringBufferIndex = unsafeBufferedLogID % logSize;
    ringBuffer1[ringBufferIndex] = -1000 * lowpassVoltage;
    ringBuffer2[ringBufferIndex] = biasVoltage;
    ringBuffer3[ringBufferIndex] = M_PI;
    ringBuffer4[ringBufferIndex] = M_PI;
    unsafeBufferedLogID += 1;
  }
}