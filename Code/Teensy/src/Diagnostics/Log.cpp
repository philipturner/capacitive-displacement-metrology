#include "Log.h"

#include "ErrorMessage.h"
#include <Arduino.h>

EXTMEM float valuesBuffer[Log::logSize * 5];
EXTMEM uint8_t flagsBuffer[Log::logSize];

void base64Encode(char* buffer, uint32_t encodedLength, uint32_t value) {
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

void Log::reset() {
  transmittedLogID = 0;
  unsafeBufferedLogID = 0;
}

void Log::transmitBufferedSamples() {
  uint64_t bufferedLogID = unsafeBufferedLogID;
  if (bufferedLogID - transmittedLogID >= logSize - 2) {
    int64_t difference = bufferedLogID - transmittedLogID;
    throwError(
      "First part of transmitBufferedSamples",
      transmittedLogID,
      bufferedLogID,
      difference);
    return;
  }

  for (uint64_t i = transmittedLogID; i < bufferedLogID; ++i) {
    char cString[28 + 1];
    cString[0] = '>';
    base64Encode(cString + 1, 1, flagsBuffer[i % logSize]);
    base64Encode(cString + 2, 5, i & 0x3FFFFFFF);
    base64Encode(cString + 7, 1, i >> 30);

    float* floatValues = valuesBuffer + (i % logSize) * 5;
    uint32_t uintValues[5];
    memcpy(uintValues, floatValues, 20);
    for (uint32_t j = 0; j < 5; ++j) {
      uint32_t value = uintValues[j] >> 8;
      auto destination = cString + 8 + 4 * j;
      base64Encode(destination, 4, value);
    }
    cString[28] = 0;

    //Serial.print(cString);
  }

  // Check that the transmitted data was valid.
  if (unsafeBufferedLogID - transmittedLogID >= logSize - 1) {
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
  int64_t number1,
  int64_t number2,
  int64_t number3
) {
  if (ErrorMessage::errorType == ErrorMessage::Type::fatal) {
    return;
  }

  ErrorMessage::reset();
  ErrorMessage::errorType = ErrorMessage::Type::recoverable;

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

float Log::encodeRawBits(uint32_t bits) {
  uint32_t uintValue = bits << 8;
  float floatValue;
  memcpy(&floatValue, &uintValue, 4);
  return floatValue;
}

void Log::write(
  Flags flags,
  float lane0,
  float lane1,
  float lane2,
  float lane3,
  float lane4
) {
  uint32_t slotID = Log::unsafeBufferedLogID % Log::logSize;
  uint32_t offset = 5 * slotID;

  valuesBuffer[offset + 0] = lane0;
  valuesBuffer[offset + 1] = lane1;
  valuesBuffer[offset + 2] = lane2;
  valuesBuffer[offset + 3] = lane3;
  valuesBuffer[offset + 4] = lane4;

  flagsBuffer[slotID] = uint8_t(flags);

  Log::unsafeBufferedLogID += 1;
}
