#include "IC/ADC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"

// MARK: - Global Variables

constexpr uint32_t loopPeriod = 7;
constexpr uint32_t logPeriod = 50; // must be divisible by loopPeriod
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

void base64Encode(uint32_t value, char* buffer, uint32_t encodedLength) {
  for (uint32_t i = 0; i < encodedLength; ++i) {
    uint32_t rightShiftAmount = 6 * i;
    uint32_t sixBits = (value >> rightShiftAmount) & 0b111111;

    char character;
    if (sixBits < 26) {
      character = 'A' + sixBits;
    } else if (sixBits < 52) {
      character = 'a' + (sixBits - 26);
    } else if (sixBits < 62) {
      character = '0'  + (sixBits - 52);
    } else if (sixBits == 62) {
      character = '+';
    } else if (sixBits == 63) {
      character = '/';
    } else {
      character = 0;
    }

    buffer[i] = character;
  }
}

void processLog() {
  if (logErrorCode != 0) {
    return;
  }

  uint32_t bufferedLogID = unsafeBufferedLogID;

  if (bufferedLogID - transmittedLogID >= logSize / 2) {
    uint32_t difference = bufferedLogID - transmittedLogID;
    logErrorCode = 1 * 1000 * 1000 + difference;
    return;
  }

  for (uint32_t i = transmittedLogID; i < bufferedLogID; ++i) {
    float bufferValues[4];
    bufferValues[0] = ringBuffer1[i % logSize];
    bufferValues[1] = ringBuffer2[i % logSize];
    bufferValues[2] = ringBuffer3[i % logSize];
    bufferValues[3] = ringBuffer4[i % logSize];

    uint32_t numbers[5];
    numbers[0] = i;
    memcpy(numbers + 1, bufferValues, 4 * sizeof(float));
    numbers[1] >>= 8;
    numbers[2] >>= 8;
    numbers[3] >>= 8;
    numbers[4] >>= 8;

    char cString[23 + 1];
    cString[0] = '>';
    base64Encode(numbers[0], cString + 1, 6);
    base64Encode(numbers[1], cString + 7, 4);
    base64Encode(numbers[2], cString + 11, 4);
    base64Encode(numbers[3], cString + 15, 4);
    base64Encode(numbers[4], cString + 19, 4);
    cString[23] = 0;

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
    processLog();
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


float lowpassVoltage = 0;

float getLowpassAlpha(float frequency, uint32_t loopPeriodMicros) {
  float sampleTimeSeconds = float(1e-6) * float(loopPeriodMicros);
  float timeConstant = 1 / (2 * M_PI * frequency);
  return sampleTimeSeconds / (timeConstant + sampleTimeSeconds);
}

void kilohertzLoop() {
  // Waveform should correct for the small timing jitter (<1 period) while
  // starting precisely at the beginning of a specific loop iteration.
  uint32_t elapsedTimeMicros = KilohertzLoop::iterationID * loopPeriod;
  uint32_t sinePeriodMicros = 1000;
  uint32_t phaseMicros = elapsedTimeMicros % sinePeriodMicros;

  if (mode == Mode::riseTime) {
    float phaseNormalized = float(phaseMicros) / float(sinePeriodMicros);
    float waveValueNormalized = triangleWave(phaseNormalized);
    biasVoltage = 10 * waveValueNormalized;
  } else if (mode == Mode::noise) {
    biasVoltage = 0;
  }
  DAC2::writeVoltage(0, biasVoltage);

  if (KilohertzLoop::iterationID % 2 == 0)  {
    auto conversion = ADC::readVoltage();
    float tiaVoltage = conversion.voltage;

    constexpr float frequency = 10000;
    float alpha = getLowpassAlpha(frequency, loopPeriod * 2);
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