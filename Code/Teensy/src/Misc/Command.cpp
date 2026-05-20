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

void decodeAttributes(char *stringBuffer, uint32_t *attributes) {
  // TODO
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
    if (length < 2)
  } else {
    if (length != 1) {
      CommandTracker::throwError(buffer, "Should be no attributes.");
      return;
    }
  }

  // Throw a soft error if the previous command was not acknowledged yet.
}

void CommandTracker::throwError(
  const char *buffer, 
  const char *reason
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
}