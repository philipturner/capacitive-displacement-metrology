#include "Log.h"

#include "ErrorMessage.h"
#include <Arduino.h>

void Log::initialize() {
  transmittedLogID = 0;
  unsafeBufferedLogID = 0;
  
  for (uint32_t i = 0; i < logSize; ++i) {
    ringBuffers[0][i] = 0;
    ringBuffers[1][i] = 0;
    ringBuffers[2][i] = 0;
    ringBuffers[3][i] = 0;
    ringBuffers[4][i] = 0;
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
  uint32_t bufferedLogID = unsafeBufferedLogID;
  if (bufferedLogID - transmittedLogID >= logSize / 2) {
    uint32_t difference = bufferedLogID - transmittedLogID;
    throwError(
      "First part of transmitBufferedSamples",
      transmittedLogID,
      bufferedLogID,
      difference);
    return;
  }

  for (uint32_t i = transmittedLogID; i < bufferedLogID; ++i) {
    float bufferValues[5];
    bufferValues[0] = ringBuffers[0][i % logSize];
    bufferValues[1] = ringBuffers[1][i % logSize];
    bufferValues[2] = ringBuffers[2][i % logSize];
    bufferValues[3] = ringBuffers[3][i % logSize];
    bufferValues[4] = ringBuffers[4][i % logSize];

    uint32_t numbers[6];
    numbers[0] = i;
    memcpy(numbers + 1, bufferValues, sizeof(bufferValues));
    numbers[1] >>= 8;
    numbers[2] >>= 8;
    numbers[3] >>= 8;
    numbers[4] >>= 8;
    numbers[5] >>= 8;

    char cString[27 + 1];
    cString[0] = '>';
    base64Encode(numbers[0], cString + 1, 6);
    base64Encode(numbers[1], cString + 7, 4);
    base64Encode(numbers[2], cString + 11, 4);
    base64Encode(numbers[3], cString + 15, 4);
    base64Encode(numbers[4], cString + 19, 4);
    base64Encode(numbers[5], cString + 23, 4);
    cString[27] = 0;

    Serial.print(cString);
  }

  // Check that the transmitted data was valid.
  if (unsafeBufferedLogID - transmittedLogID >= logSize) {
    uint32_t difference = unsafeBufferedLogID - transmittedLogID;
    throwError(
      "Second part of transmitBufferedSamples",
      transmittedLogID,
      unsafeBufferedLogID,
      difference);
    return;
  }
  transmittedLogID = bufferedLogID;
}

void Log::throwError(
  const char *cString, 
  int32_t number1,
  int32_t number2,
  int32_t number3
) {
  if (ErrorMessage::errorType == ErrorMessage::Type::fatal) {
    return;
  }

  ErrorMessage::reset();
  ErrorMessage::errorType = ErrorMessage::Type::fatal;

  ErrorMessage::addString("Log failed.");
  ErrorMessage::addNewline();
  ErrorMessage::addString(cString);
  ErrorMessage::addNewline();

  ErrorMessage::addInteger(number1);
  ErrorMessage::addNewline();
  ErrorMessage::addInteger(number2);
  ErrorMessage::addNewline();
  ErrorMessage::addInteger(number3);
  ErrorMessage::addNewline();
}