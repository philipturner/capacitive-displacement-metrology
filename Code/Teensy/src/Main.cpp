#include "IC/ADC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"

// MARK: - Global Variables

// loopPeriod = 12, buffer time = 10 ms, 45 bytes/line
//
// logPeriod = 48  | froze permanently
// logPeriod = 120 | froze permanently
// logPeriod = 480 |

// loopPeriod = 12, buffer time = 50 ms, 45 bytes/line
//
// logPeriod = 48  | unstable, can freeze at 10s or 40s
// logPeriod = 72  | 15s hiccup at 60s, froze at 150s, resumed ~1 min later
// logPeriod = 120 | spotted two hiccups, but stable for >4 min, froze for 1-2 min on another attempt and was still breaking down
// logPeriod = 240 | stable (>2 min)
// logPeriod = 480 | stable (>2 min)

// loopPeriod = 12, buffer time = 200 ms, 45 bytes/line
//
// logPeriod = 48  | froze for ~20s
// logPeriod = 120 |
// logPeriod = 480 |

// The in-memory history is fine, but we cannot constantly stream data to the
// PC. Data needs to be sent only on request.

constexpr uint32_t loopPeriod = 12;
constexpr uint32_t logPeriod = 480; // must be divisible by loopPeriod
constexpr uint32_t logSize = 12000;
float ringBuffer1[logSize];
float ringBuffer2[logSize];
float ringBuffer3[logSize];
float ringBuffer4[logSize];
uint32_t transmittedLogID = 0;
uint32_t unsafeBufferedLogID = 0; // constantly overwritten by interrupt
uint32_t logErrorCode = 0;

float biasVoltage = 0;

enum class Mode {
  noise = 0,
  riseTime = 1,
};
Mode mode = Mode::riseTime;

// MARK: - Program

void kilohertzLoop();

void setup() {
  Application::setupSerial();
  Application::setupSPI();

  for (uint32_t i = 0; i < logSize; ++i) {
    ringBuffer1[i] = 0;
    ringBuffer2[i] = 0;
    ringBuffer3[i] = 0;
    ringBuffer4[i] = 0;
  }

  KilohertzLoop::initialize(kilohertzLoop, loopPeriod);
}

// MARK: - Serial Loop

void processLog() {
  if (logErrorCode != 0) {
    return;
  }

  uint32_t bufferedLogID = unsafeBufferedLogID;

  if (bufferedLogID - transmittedLogID >= logSize - 100) {
    uint32_t difference = bufferedLogID - transmittedLogID;
    logErrorCode = 1 * 1000 * 1000 + difference;
    return;
  }

  for (uint32_t i = transmittedLogID; i < bufferedLogID; ++i) {
    // 2231 μs for 1670 lines
    float bufferValues[4];
    bufferValues[0] = ringBuffer1[i % logSize];
    bufferValues[1] = ringBuffer2[i % logSize];
    bufferValues[2] = ringBuffer3[i % logSize];
    bufferValues[3] = ringBuffer4[i % logSize];

    constexpr uint32_t channelCount = 5;

    uint32_t numbers[channelCount];
    numbers[0] = i;
    memcpy(numbers + 1, bufferValues, 4 * sizeof(float));

    char cString[channelCount * 8 + 5];
    cString[0] = '>';
    cString[channelCount * 8 + 1] = '<';
    cString[channelCount * 8 + 2] = '\r';
    cString[channelCount * 8 + 3] = '\n';
    cString[channelCount * 8 + 4] = 0;

    for (uint32_t numberID = 0; numberID < channelCount; ++numberID) {
      uint32_t number = numbers[numberID];
      for (uint32_t charID = 0; charID < 8; ++charID) {
        uint32_t leftShiftAmount = 4 * charID;
        uint32_t fourBits = (number >> leftShiftAmount) & 0b1111;

        uint32_t indexInString = 1 + 8 * numberID + charID;
        cString[indexInString] = 'a' + char(fourBits);
      }
    }

    Serial.print(cString);
  }

  // Check that the transmitted data was valid.
  if (unsafeBufferedLogID - transmittedLogID >= logSize) {
    logErrorCode = 2 * 1000 * 1000;
    return;
  }
  transmittedLogID = bufferedLogID;
}

void processInput() {
  char incomingByte = Serial.read();

  if (incomingByte == 'n') {
    mode = Mode::noise;
  } else if (incomingByte == 'r') {
    mode = Mode::riseTime;
  } else if (incomingByte == 'c') {
    logErrorCode = 0;
    transmittedLogID = unsafeBufferedLogID;
  }
}

void loop() {
  delay(50);

  if (KilohertzLoop::errorCode != 0) {
    Serial.print("KilohertzLoop failed with error code: ");
    Serial.print(KilohertzLoop::errorCode);
    Serial.println();
  } else if (logErrorCode != 0) {
    Serial.print("log failed with error code: ");
    Serial.print(logErrorCode);
    Serial.println();
  } else {
    Serial.println("Something is happening.");
    processLog();
  }

  if (Serial.available() > 0) {
    processInput();

    // Prevent accidents from multiple key presses.
    while (Serial.available() > 0) {
      char byte = Serial.read();
      Serial.print("ignored input: ");
      Serial.print(byte);
      Serial.println();
    }
  }
}

// MARK: - Kilohertz Loop

float sineWave(float phaseNormalized) {
  return sin(phaseNormalized * 2 * M_PI);
}

float squareWave(float phaseNormalized) {
  if (phaseNormalized < 0.5) {
    return 1.0;
  } else {
    return -1.0;
  }
}

float triangleWave(float phaseNormalized) {
  float progress;
  if (phaseNormalized < 0.5) {
    progress = 2 * phaseNormalized;
  } else {
    progress = 2 * (1 - phaseNormalized);
  }

  return 2 * progress - 1;
}

constexpr float lowpassFrequency = 10000;
float lowpassVoltage = 0;

float getLowpassAlpha() {
  float sampleTimeSeconds = float(1e-6) * float(loopPeriod * 2);
  float timeConstant = 1 / (2 * M_PI * lowpassFrequency);
  return sampleTimeSeconds / (timeConstant + sampleTimeSeconds);
}

void kilohertzLoop() {
  uint32_t elapsedTime = KilohertzLoop::latestTimestamp - KilohertzLoop::startTimestamp;
  uint32_t sinePeriod = 1000; // in microseconds
  uint32_t phase = elapsedTime % sinePeriod;

  if (mode == Mode::riseTime) {
    float phaseNormalized = float(phase) / float(sinePeriod);
    float waveValueNormalized = triangleWave(phaseNormalized);
    biasVoltage = 10 * waveValueNormalized;
  } else if (mode == Mode::noise) {
    biasVoltage = 0;
  }
  DAC2::writeVoltage(0, biasVoltage);
  
  {
    auto conversion = ADC::readVoltage();
    float tiaVoltage = conversion.voltage;

    float alpha = getLowpassAlpha();
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