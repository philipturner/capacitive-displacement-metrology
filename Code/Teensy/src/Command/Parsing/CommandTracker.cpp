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

bool checkNumAttributes(Command command, uint32_t numAttributes) {
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

  return true;
}

bool checkAttributes(Command command) {
  if (command.mode == Command::Mode::simpleScanning) {
    uint32_t frequency = command.attributes[0];
    if (frequency == 0 || frequency > 10000) {
      CommandTracker::throwError("Invalid frequency.");
      return false;
    }
  } else if (command.mode == Command::Mode::imaging) {
    uint32_t resolution = command.attributes[0];
    if (resolution == 0 || resolution > 1024 || (resolution % 2 != 0)) {
      CommandTracker::throwError("Invalid resolution.");
      return false;
    }
  }

  return true;
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
  uint32_t modeCode;
  uint32_t remainderOffset;
  if (!CommandParsing::findModeCode(length, modeCode, remainderOffset)) {
    return;
  }
  command.mode = Command::Mode(modeCode);

  // Decode the alphabetic code attribute.
  if (length >= remainderOffset) {
    command.alphaCode = uint32_t(buffer[remainderOffset]);
  }
  if (!CommandParsing::checkAlphaCode(command)) {
    return;
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