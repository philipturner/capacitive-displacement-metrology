#include "Log.h"

#include <Arduino.h>

void Log::initialize() {
  transmittedLogID = 0;
  unsafeBufferedLogID = 0;
  errorCode = 0;
  
  for (uint32_t i = 0; i < logSize; ++i) {
    ringBuffers[0][i] = 0;
    ringBuffers[1][i] = 0;
    ringBuffers[2][i] = 0;
    ringBuffers[3][i] = 0;
  }
}

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

void Log::transmitBufferedSamples() {
  if (errorCode != 0) {
    return;
  }

  uint32_t bufferedLogID = unsafeBufferedLogID;

  if (bufferedLogID - transmittedLogID >= logSize / 2) {
    uint32_t difference = bufferedLogID - transmittedLogID;
    errorCode = 1 * 1000 * 1000 + difference;
    return;
  }

  for (uint32_t i = transmittedLogID; i < bufferedLogID; ++i) {
    float bufferValues[4];
    bufferValues[0] = ringBuffers[0][i % logSize];
    bufferValues[1] = ringBuffers[1][i % logSize];
    bufferValues[2] = ringBuffers[2][i % logSize];
    bufferValues[3] = ringBuffers[3][i % logSize];

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
    errorCode = 2 * 1000 * 1000;
    return;
  }
  transmittedLogID = bufferedLogID;
}