#include "IC/ADC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Time/KilohertzLoop.h"
#include "Time/Log.h"
#include "Util/Application.h"
#include "Util/FilterUtil.h"

// MARK: - Global Variables

constexpr uint32_t loopPeriod = 12;
constexpr uint32_t capacitanceWavePeriod = 1008;
constexpr uint32_t capacitanceWaveCount = 10;
constexpr float capacitanceStimulusAmplitude = 12;

float lowpassFilteredCurrent = 0;
float biasVoltage = 0;
float capacitance = 0;
float phaseShift = 0;

int32_t zeroCrossingTrackerIterationID = 0;
int32_t zeroCrossingIterationID = -1;
float sineSquaredAccumulator = 0;
float cosineSquaredAccumulator = 0;
uint32_t rmsCurrentSampleCount = 0;

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
    uint32_t timeSinceSpike = micros() - startTrueTime;
    if (iterationDelta > 0 && timeSinceSpike > 0) {
      if (rmsCurrentSampleCount != iterationsPerMeasurement) {
        Serial.println("Unexpected behavior in capacitance measurement");
        Serial.println(rmsCurrentSampleCount);
        Serial.println(iterationsPerMeasurement);
        exit(0);
      }

      float n = float(rmsCurrentSampleCount);
      float sineSquaredMixed = sineSquaredAccumulator / n;
      float cosineSquaredMixed = cosineSquaredAccumulator / n;
      float signalMax = sqrt(sineSquaredMixed + cosineSquaredMixed) * 2;

      float frequency = float(1e6) / float(capacitanceWavePeriod);
      float stimulus = capacitanceStimulusAmplitude;
      float slewRateMax = stimulus * 2 * M_PI * frequency;
      capacitance = signalMax / slewRateMax;

      // This is a confirmed error. I tested it with a simulated waveform
      // from 7.00 fF capacitance and the bias voltage, but the measured
      // capacitance was 9.91 fF (a factor of 1.416 higher).
      capacitance *= M_SQRT1_2;
      
      int32_t iterations = zeroCrossingIterationID;
      iterations -= zeroCrossingTrackerIterationID;
      float timeLag = float(iterations) * float(loopPeriod);
      timeLag -= float(capacitanceWavePeriod);

      float servoLoopLag = 0;
      servoLoopLag += 2.4; // DAC
      servoLoopLag += 10; // ADC 100 kSPS sampling
      servoLoopLag += 29; // 3 poles (10 kHz, 24 kHz, 24 kHz)
      timeLag -= servoLoopLag;

      float relativeTimeLag = timeLag / float(capacitanceWavePeriod);
      phaseShift = -relativeTimeLag * 360;
      if (phaseShift > 180) {
        phaseShift -= 360;
      }
    }

    zeroCrossingTrackerIterationID = KilohertzLoop::iterationID;
    zeroCrossingIterationID = -1;
    sineSquaredAccumulator = 0;
    cosineSquaredAccumulator = 0;
    rmsCurrentSampleCount = 0;
  }
}

void kilohertzLoop() {
  updateMode();
  if (mode == Mode::capacitance) {
    updateCapacitance();
  }

  float referenceSine = 0;
  float referenceCosine = 0;
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
    uint32_t elapsedTime = micros() - startTrueTime;
    uint32_t phase = elapsedTime % capacitanceWavePeriod;

    float phaseNormalized = float(phase) / float(capacitanceWavePeriod);
    referenceSine = sin(phaseNormalized * 2 * M_PI);
    referenceCosine = cos(phaseNormalized * 2 * M_PI);
    biasVoltage = capacitanceStimulusAmplitude * referenceSine;
  }
  DAC2::writeVoltage(0, biasVoltage);

  {
    auto conversion = ADC::readVoltage();
    float tiaVoltage = conversion.voltage;
    float current = tiaVoltage / -1e9;
    float previousFilteredCurrent = lowpassFilteredCurrent;

    constexpr float frequency = 10000;
    float alpha = FilterUtil::getLowpassAlpha(frequency, loopPeriod * 2);
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
    Log::ringBuffers[3][ringIndex] = phaseShift;

    Log::unsafeBufferedLogID += 1;
  }
}