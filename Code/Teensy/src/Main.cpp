#include "IC/ADC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Time/KilohertzLoop.h"
#include "Time/Log.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/FilterUtil.h"

// MARK: - Global Variables

uint32_t loopPeriod = 7;

float lowpassFilteredCurrent = 0;
float biasVoltage = 0;
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
Mode mode = Mode::riseTime;

// MARK: - Program

void kilohertzLoop();

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Log::initialize();
  KilohertzLoop::initialize(kilohertzLoop, loopPeriod);
}

// MARK: - Serial Loop



void processInput() {
  char incomingByte = Serial.read();

  if (incomingByte == 'n') {
    mode = Mode::noise;
  } else if (incomingByte == 'r') {
    mode = Mode::riseTime;
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

void kilohertzLoop() {
  // Waveform should correct for the small timing jitter (<1 period) while
  // starting precisely at the beginning of a specific loop iteration.
  //
  // We definitely want this for maximum fidelity when generating
  // smooth capacitive bias voltage waveforms @ 143 kHz.
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