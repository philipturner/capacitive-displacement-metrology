#include "Command.h"

#include "../Diagnostics/ErrorMessage.h"
#include <Arduino.h>

void extractInput(char *buffer, uint32_t& length) {
  length = 0;
  for (uint32_t i = 0; i < 50; ++i) {
    if (Serial.available() <= 0) {
      break;
    }

    char incomingByte = Serial.read();
    buffer[i] = incomingByte;
    length = i + 1;
  }
  buffer[length] = 0; // null-terminate
}

bool isDigit(char x) {
  if (x >= '0' && x <= '9') {
    return true;
  } else {
    return false;
  }
}

bool decodeAttributes(
  const char *stringBuffer,
  uint32_t stringLength,
  uint32_t *attributes,
  uint32_t &numAttributes
) {
  uint32_t accumulator = 0;
  for (uint32_t i = 0; i < stringLength; ++i) {
    if (stringBuffer[i] == ',' || i == stringLength - 1) {
      attributes[numAttributes] = accumulator;
      numAttributes += 1;
      accumulator = 0;
      continue;
    }

    if (!isDigit(stringBuffer[i])) {
      CommandTracker::throwError(
        stringBuffer, 
        "Character at index is not a digit", 
        i);
      return false;
    }

    uint8_t digit = uint8_t(stringBuffer[i] - '0');
    accumulator = accumulator * 10 + digit;
  }
  return true;
}

bool checkBlindSteppingAttributes(
  const char *stringBuffer,
  Command command, 
  uint32_t numAttributes
) {
  char code = char(command.attributes[0]);

  uint32_t expectedNumAttributes;
  if (code == 'u') {
    expectedNumAttributes = 1;
  } else if (code == 'd') {
    expectedNumAttributes = 1;
  } else if (code == 'c') {
    expectedNumAttributes = 2;
  } else {
    Serial.println("This should never happen.");
    exit(0);
  }

  if (numAttributes != expectedNumAttributes) {
    CommandTracker::throwError(
      stringBuffer, 
      "Unexpected number of attributes.",
      expectedNumAttributes,
      numAttributes);
    return false;
  }
  return true;
}

bool CommandTracker::registerCommand(Command command) {
  // Throw a soft error if the previous command was not acknowledged yet.
  if (latestCommandID != acknowledgedCommandID) {

  }
}

void CommandTracker::processSerialInput() {
  char buffer[50];
  uint32_t length = 0;
  extractInput(buffer, length);
  if (length >= 50) {
    Serial.println("Command tracker was overloaded with input commands.");
    exit(0);
  }
  Command command;
  
  // Decode the mode.
  if (length == 0) {
    return;
  }
  if (!isDigit(buffer[0])) {
    CommandTracker::throwError(buffer, "First character not digit.");
    return;
  }

  uint8_t modeCode = uint8_t(buffer[0] - '0');
  if (modeCode > 4) {
    CommandTracker::throwError(buffer, "Invalid mode code.");
    return;
  }
  command.mode = Command::Mode(modeCode);

  // Decode the attributes.
  if (command.mode == Command::Mode::blindStepping) {
    if (length < 2) {
      CommandTracker::throwError(
        buffer, "Not enough characters to decode the alphabetic code.");
      return;
    }

    if (buffer[1] == 'u' ||
        buffer[1] == 'd' ||
        buffer[1] == 'c') {
      command.attributes[0] = uint32_t(buffer[1]);
    } else {
      CommandTracker::throwError(
        buffer, "Invalid character for alphabetic code.");
      return;
    }

    uint32_t numAttributes;
    bool decodeAttributesWorked = decodeAttributes(
      buffer + 2, 
      length - 2, 
      command.attributes + 1,
      numAttributes);
    if (!decodeAttributesWorked) {
      return;
    }
    if (!checkBlindSteppingAttributes(buffer, command, numAttributes)) {
      return;
    }
  } else {
    if (length != 1) {
      CommandTracker::throwError(buffer, "Should be no attributes.");
      return;
    }
  }

  lock = true;
  bool registerCommandWorked = registerCommand(command);
  lock = false;
  if (!registerCommandWorked) {
    return;
  }
}

void CommandTracker::throwError(
  const char *buffer, 
  const char *reason,
  int32_t number1,
  int32_t number2
) {
  if (ErrorMessage::hasError()) {
    return;
  }

  ErrorMessage::reset();
  ErrorMessage::errorType = ErrorMessage::Type::recoverable;

  ErrorMessage::addString("Invalid command.");
  ErrorMessage::addNewline();
  ErrorMessage::addString(buffer);
  ErrorMessage::addNewline();
  ErrorMessage::addString(reason);
  ErrorMessage::addNewline();

  ErrorMessage::addInteger(number1);
  ErrorMessage::addNewline();
  ErrorMessage::addInteger(number2);
  ErrorMessage::addNewline();
}