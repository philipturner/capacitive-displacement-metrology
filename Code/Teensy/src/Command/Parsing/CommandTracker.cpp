#include "Command.h"

#include "Command/Imager/Imager.h"
#include "Command/SimpleScanner.h"
#include "Diagnostics/ErrorMessage.h"
#include <Arduino.h>

void extractInput(uint32_t& length) {
  length = 0;
  for (uint32_t i = 0; i < 50; ++i) {
    if (Serial.available() <= 0) {
      break;
    }

    char incomingByte = Serial.read();
    CommandTracker::buffer[i] = incomingByte;
    length = i + 1;
  }
  CommandTracker::buffer[length] = 0; // null-terminate
}

bool isRecoverCommand(uint32_t length) {
  if (length != 7) {
    return false;
  }

  const char *expectedString = "recover";
  for (uint32_t i = 0; i < 7; ++i) {
    char actual = CommandTracker::buffer[i];
    char expected = expectedString[i];
    if (actual != expected) {
      return false;
    }
  }

  return true;
}

bool isDigit(char x) {
  if (x >= '0' && x <= '9') {
    return true;
  } else {
    return false;
  }
}

int32_t findModeCode(
  uint32_t length,
  uint32_t &remainderOffset
) {
  remainderOffset = 0;

  if (isDigit(CommandTracker::buffer[0])) {
    remainderOffset += 1;
  } else {
    CommandTracker::throwError("First character not digit.");
    return -1;
  }

  if (length > 1 && isDigit(CommandTracker::buffer[1])) {
    remainderOffset += 1;
  }

  uint32_t accumulator = 0;
  for (uint32_t i = 0; i < remainderOffset; ++i) {
    uint8_t digit = uint8_t(CommandTracker::buffer[i] - '0');
    accumulator = accumulator * 10 + digit;
  }
  if (accumulator >= uint8_t(Command::Mode::NUM_MODES)) {
    CommandTracker::throwError("Invalid mode code.");
    return -1;
  }
  return accumulator;
}

bool findAlphaCode(char code, const char *cString) {
  for (uint32_t i = 0; i < 50; ++i) {
    if (cString[i] == 0) {
      break;
    }
    if (cString[i] == code) {
      return true;
    }
  }
  return false;
}

bool checkAttributes(
  Command command, 
  uint32_t numAttributes
) {
  // Check the number of attributes.

  uint32_t expectedNumAttributes = 0;
  if (command.mode == Command::Mode::dacTest) {
    expectedNumAttributes = 1;
  }
  if (command.mode == Command::Mode::blindStepping) {
    if (command.alphaCode == 'u') {
      expectedNumAttributes = 1;
    } else if (command.alphaCode == 'd') {
      expectedNumAttributes = 1;
    } else if (command.alphaCode == 'c') {
      expectedNumAttributes = 2;
    }
  }
  if (command.mode == Command::Mode::spectroscopy) {
    if (command.alphaCode == 'a') {
      expectedNumAttributes = 1;
    } else if (command.alphaCode == 'c') {
      expectedNumAttributes = 2;
    }
  }
  if (command.mode == Command::Mode::simpleScanning) {
    expectedNumAttributes = 2;
  }
  if (command.mode == Command::Mode::imaging) {
    if (command.alphaCode == 'i') {
      expectedNumAttributes = 4;
    } else if (command.alphaCode == 'v') {
      expectedNumAttributes = 4;
    } else if (command.alphaCode == 'd') {
      expectedNumAttributes = 6;
    }
  }
  if (command.mode == Command::Mode::imagingSettings) {
    expectedNumAttributes = 1;
  }

  if (numAttributes != expectedNumAttributes) {
    CommandTracker::throwError(
      "Unexpected number of attributes.",
      expectedNumAttributes,
      numAttributes);
    return false;
  }

  // Check the values of the attributes.

  if (command.mode == Command::Mode::simpleScanning) {
    return SimpleScanner::checkAttributes(command);
  } else if (command.mode == Command::Mode::imaging) {
    return Imager::checkAttributes(command);
  } else {
    return true;
  }
}

void CommandTracker::processSerialInput() {
  // Copy the input to the buffer.
  uint32_t length = 0;
  extractInput(length);
  if (length >= 50) {
    Serial.println("Command tracker was overloaded with input commands.");
    exit(0);
  }
  if (length == 0) {
    return;
  }
  Command command;

  // Check for the recover command.
  if (ErrorMessage::hasError()) {
    if (isRecoverCommand(length)) {
      if (ErrorMessage::errorType == ErrorMessage::Type::recoverable) {
        ErrorMessage::reset();
      }
      return;
    }
  }
  
  // Decode the mode.
  uint32_t remainderOffset;
  int32_t modeCode = findModeCode(length, remainderOffset);
  if (modeCode < 0) {
    return;
  }
  command.mode = Command::Mode(modeCode);

  // Decode the alphabetic code attribute.
  if (length >= remainderOffset) {
    command.alphaCode = uint32_t(buffer[remainderOffset]);
  }
  if (command.mode == Command::Mode::dacTest) {
    if (!findAlphaCode(command.alphaCode, "xyzb")) {
      throwError("Invalid character for alphabetic code.");
      return;
    }
  } else if (command.mode == Command::Mode::blindStepping) {
    if (!findAlphaCode(command.alphaCode, "udc")) {
      throwError("Invalid character for alphabetic code.");
      return;
    }
  } else if (command.mode == Command::Mode::spectroscopy) {
    if (!findAlphaCode(command.alphaCode, "ac")) {
      throwError("Invalid character for alphabetic code.");
      return;
    }
  } else if (command.mode == Command::Mode::simpleScanning) {
    if (!findAlphaCode(command.alphaCode, "xy")) {
      throwError("Invalid character for alphabetic code.");
      return;
    }
  } else if (command.mode == Command::Mode::imaging) {
    if (!findAlphaCode(command.alphaCode, "ivd")) {
      throwError("Invalid character for alphabetic code.");
      return;
    }
  } else if (command.mode == Command::Mode::imagingSettings) {
    if (!findAlphaCode(command.alphaCode, "axy")) {
      throwError("Invalid character for alphabetic code.");
      return;
    }
  } else {
    if (command.alphaCode != 0) {
      throwError("There should be no alpha code.");
      return;
    }
  }

  // Decode the remaining attributes.
  uint32_t numAttributes = 0;
  if (length > remainderOffset) {
    bool decodeAttributesWorked = decodeAttributes(
      buffer + remainderOffset, 
      length - remainderOffset, 
      command.attributes,
      numAttributes);
    if (!decodeAttributesWorked) {
      return;
    }
  }
  if (!checkAttributes(command, numAttributes)) {
    return;
  }

  // Register the new command.
  lock = true;
  bool registerCommandWorked = registerCommand(command);
  lock = false;
  if (!registerCommandWorked) {
    return;
  }
}

bool CommandTracker::registerCommand(Command command) {
  // Throw a soft error if the previous command was not acknowledged yet.
  if (latestCommandID != acknowledgedCommandID) {
    throwError(
      "Previous command was not acknowledged.",
      latestCommandID,
      acknowledgedCommandID);
    return false;
  }

  latestCommandID += 1;
  latestCommand = command;
  return true;
}

void CommandTracker::throwError(
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

  // Ensure there's a valid, null-terminated C string here.
  buffer[50] = 0;
  ErrorMessage::addString(buffer);
  ErrorMessage::addNewline();
  ErrorMessage::addString(reason);
  ErrorMessage::addNewline();

  ErrorMessage::addInteger(number1);
  ErrorMessage::addNewline();
  ErrorMessage::addInteger(number2);
  ErrorMessage::addNewline();
}

bool CommandTracker::nextCommand(Command &nextCommand) {
  if (lock) {
    return false;
  }
  if (latestCommandID == acknowledgedCommandID) {
    return false;
  }

  nextCommand = latestCommand;
  acknowledgedCommandID += 1;
  return true;
}