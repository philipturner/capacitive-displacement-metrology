#include "IC/ADC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"

// MARK: - Global Variables

constexpr uint32_t loopPeriod = 6;
constexpr uint32_t logPeriod = 6 * 5; // must be divisible by loopPeriod
constexpr uint32_t logSize = 7000;
float ringBuffer1[logSize];
float ringBuffer2[logSize];
float ringBuffer3[logSize];
float ringBuffer4[logSize];
uint32_t transmittedLogID = 0;
uint32_t unsafeBufferedLogID = 0; // constantly overwritten by interrupt

float biasVoltage = 0;

enum class Mode {
  noise = 0,
  riseTime = 1,
};
Mode mode = Mode::noise;

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
  uint32_t bufferedLogID = unsafeBufferedLogID;

  // This does not catch all conditions where the fast loop outpaces the slow
  // loop.
  if (bufferedLogID - transmittedLogID >= logSize) {
    Serial.println("Unable to process the log.");
    KilohertzLoop::throwError(4000);
    return;
  }

  uint32_t startMicros = micros();

  for (uint32_t i = transmittedLogID; i < bufferedLogID; ++i) {
    // 2231 μs for 1670 lines
    float bufferValues[4];
    bufferValues[0] = ringBuffer1[i % logSize];
    bufferValues[1] = ringBuffer2[i % logSize];
    bufferValues[2] = ringBuffer3[i % logSize];
    bufferValues[3] = ringBuffer4[i % logSize];

    uint32_t numbers[5];
    numbers[0] = i;
    memcpy(numbers + 1, bufferValues, 16);

    char cString[45];
    cString[0] = '>';
    cString[41] = '<';
    cString[42] = '\r';
    cString[43] = '\n';
    cString[44] = 0;

    for (uint32_t numberID = 0; numberID < 5; ++numberID) {
      uint32_t number = numbers[numberID];
      for (uint32_t charID = 0; charID < 8; ++charID) {
        uint32_t leftShiftAmount = 4 * charID;
        uint32_t fourBits = (number >> leftShiftAmount) & 0b1111;

        uint32_t indexInString = 1 + 8 * numberID + charID;
        cString[indexInString] = 'a' + char(fourBits);
      }
    }

    Serial.print(cString);

    // 80000 μs for 5000 lines
    /*
    // Identifier to debug serial acquisition.
    Serial.print(">");
    Serial.print("id:");
    Serial.print(i);
    Serial.print(",");
    
    Serial.printf("%f", ringBuffer1[i % logSize]);
    Serial.print(",");

    Serial.printf("%f", ringBuffer2[i % logSize]);
    Serial.print(",");

    Serial.printf("%f", ringBuffer3[i % logSize]);
    Serial.print(",");

    Serial.printf("%f", ringBuffer4[i % logSize]);
    Serial.print(",");
    
    Serial.print("<");
    Serial.println();
    */

    // 2500 μs for 1670 lines
    // >id:19762,-0.800607,0.000000,3.141593,3.141593,<
  }

  uint32_t endMicros = micros();

  Serial.print("time: ");
  Serial.print(endMicros - startMicros);
  Serial.println();

  // Check that the transmitted data was valid.
  if (unsafeBufferedLogID - transmittedLogID >= logSize) {
    Serial.println(transmittedLogID);
    Serial.println(bufferedLogID);
    Serial.println(unsafeBufferedLogID);
    Serial.println("Unable to process the log.");
    KilohertzLoop::throwError(5000);
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
  }
}

void loop() {
  delay(50);

  if (KilohertzLoop::errorCode != 0) {
    Serial.print("KilohertzLoop failed with error code: ");
    Serial.print(KilohertzLoop::errorCode);
    Serial.println();
    return;
  } else {
    Serial.println("Something is happening.");
  }

  processLog();

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
    DAC2::writeVoltage(0, biasVoltage);
  }
  
  if (KilohertzLoop::iterationID % 2 == 0) {
    auto conversion = ADC::readVoltage();
    float tiaVoltage = conversion.voltage;

    float alpha = getLowpassAlpha();
    lowpassVoltage = alpha * tiaVoltage + (1 - alpha) * lowpassVoltage;
  } else {
    // Should have a more principled way to handle state transitions.
    if (mode == Mode::noise && biasVoltage != 0) {
      biasVoltage = 0;
      DAC2::writeVoltage(0, biasVoltage);
    }
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