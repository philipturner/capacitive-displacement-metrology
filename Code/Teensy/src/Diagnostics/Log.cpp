#include "Log.h"

#include "ErrorMessage.h"
#include <Arduino.h>

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
  if (bufferedLogID - transmittedLogID >= logSize - 2) {
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

void Log::writeValues(
  float lane0,
  float lane1,
  float lane2,
  float lane3,
  float lane4,
  uint8_t flags
) {
  uint32_t slotID = Log::unsafeBufferedLogID % Log::logSize;
  uint32_t offset = 5 * slotID;

  valuesBuffer[offset + 0] = lane0;
  valuesBuffer[offset + 1] = lane1;
  valuesBuffer[offset + 2] = lane2;
  valuesBuffer[offset + 3] = lane3;
  valuesBuffer[offset + 4] = lane4;

  flagsBuffer[slotID] = flags;

  Log::unsafeBufferedLogID += 1;
}

void Log::recordNormalMessage(Command::Mode mode) {
  uint32_t slotID = Log::unsafeBufferedLogID % Log::logSize;
    for (uint32_t i = 0; i < 5; ++i) {
      Log::ringBuffers[i][slotID] = 0;
    }

    if (mode == Command::Mode::idle) {
      Log::ringBuffers[0][slotID] = Application::state.filteredCurrent;
    } else if (mode == Command::Mode::dacTest) {
      dacTester.writeToLog(slotID);
    } else if (mode == Command::Mode::capacitanceReporting) {
      Log::ringBuffers[0][slotID] = Application::state.filteredCurrent;
      Log::ringBuffers[1][slotID] = Application::state.biasVoltage;
      Log::ringBuffers[2][slotID] = Application::state.capacitance;
      Log::ringBuffers[3][slotID] = Application::state.phaseShift;
    } else if (mode == Command::Mode::blindStepping) {
      Log::ringBuffers[0][slotID] = Application::state.filteredCurrent;
      Log::ringBuffers[1][slotID] = Application::state.piezoZVoltage;
      Log::ringBuffers[2][slotID] = Application::state.capacitance;
      Log::ringBuffers[3][slotID] = Application::state.phaseShift;
    } else if (mode == Command::Mode::tipApproach) {
      tipApproacher.writeToLog(slotID);
    }

    Log::unsafeBufferedLogID += 1;
}

void Log::recordModeChange(Command::Mode newMode) {

}