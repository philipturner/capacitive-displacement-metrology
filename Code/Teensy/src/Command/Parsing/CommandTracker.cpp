#include "CommandTracker.h"

#include "Command/Parsing/CommandParsing.h"
#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
#include "Filter/Feedback.h"
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

uint32_t getExpectedNumAttributes(Command command, uint32_t numAttributes) {
  switch (command.mode) {
    case Command::Mode::dacTest: {
      return 1;
    }
    case Command::Mode::blindStepping: {
      if (command.alphaCode == 'c') {
        return 2;
      } else {
        return 1;
      }
    }
    case Command::Mode::spectroscopy: {
      if (command.alphaCode == 'a') {
        return 1;
      } else {
        return 2;
      }
    }
    case Command::Mode::simpleScanning: {
      return 2;
    }
    case Command::Mode::imaging: {
      return 3;
    }
    case Command::Mode::imagingSettings: {
      switch (command.alphaCode) {
        case 'a': return 1;
        case 'f': return 1;
        case 'l': return 1;
        case 'o': return 3;
        case 'r': return 0;
        case 's': return 1;
        default: return 0;
      }
    }
    case Command::Mode::creepSettings: {
      return 1;
    }
    case Command::Mode::tiltCalculation: {
      switch (command.alphaCode) {
        case 'c': return 2;
        case 'o': return 4;
      }
    }
    case Command::Mode::tiltSettings: {
      return 2;
    }
    default: {
      return 0;
    }
  }
}

bool checkAttributes(Command command) {
  switch (command.mode) {
    case Command::Mode::blindStepping: {
      if (command.attributes[0] < 0) {
        CommandTracker::bounceError("Invalid step count.");
        return false;
      }
      if (command.alphaCode == 'c') {
        float capacitance = command.attributes[1];
        if (capacitance <= 0) {
          CommandTracker::bounceError("Invalid capacitance.");
          return false;
        }
      }
      break;
    }
    case Command::Mode::simpleScanning: {
      float frequency = command.attributes[0];
      if (frequency <= 0) {
        CommandTracker::bounceError("Invalid frequency.");
        return false;
      }
      break;
    }
    case Command::Mode::imaging: {
      for (uint32_t i = 0; i < 2; ++i) {
        uint32_t resolution = command.attributes[i];
        if (resolution == 0 || resolution > 1024 || (resolution % 2 != 0)) {
          CommandTracker::bounceError("Invalid resolution.");
          return false;
        }
      }

      float size = command.attributes[2];
      if (size <= 0 || size > 270) {
        CommandTracker::bounceError("Invalid image size.");
        return false;
      }

      break;
    }
    case Command::Mode::imagingSettings: {
      switch (command.alphaCode) {
        case 'a': {
          uint8_t axisCode = command.attributes[0];
          if (axisCode != 0 && axisCode != 1) {
            CommandTracker::bounceError("Invalid axis code.");
            return false;
          }
          break;
        }
        case 'f': {
          float timeConstant = command.attributes[0];
          float limit = float(Feedback::defaultTimeConstant) * 1e-3;
          if (timeConstant < limit) {
            CommandTracker::bounceError("Invalid feedback time constant.");
            return false;
          }
          break;
        }
        case 'o': {
          uint8_t centerID = command.attributes[0];
          if (centerID != 0 && centerID != 1) {
            CommandTracker::bounceError("Invalid center ID.");
            return false;
          }
          break;
        }
        case 'l':
        case 's': {
          float time = command.attributes[0];
          if (time < 0) {
            CommandTracker::bounceError("Invalid time.");
            return false;
          }
          break;
        }
      }
      break;
    }
    case Command::Mode::tiltCalculation: {
      float displacement = command.attributes[0];
      if (abs(displacement) < 0.1 || abs(displacement) > 135) {
        CommandTracker::bounceError("Invalid displacement.");
        return false;
      }

      float millisecondsPerDisplacement = command.attributes[1];
      if (millisecondsPerDisplacement < 2) {
        CommandTracker::bounceError("Invalid time.");
        return false;
      }

      break;
    }
    case Command::Mode::tiltSettings: {
      float dzdx = command.attributes[0];
      float dzdy = command.attributes[1];
      float greatestMagnitude = max(abs(dzdx), abs(dzdy));
      if (greatestMagnitude > 0.5) {
        CommandTracker::bounceError("Invalid slope.");
        return false;
      }
      break;
    }
    default: {
      break;
    }
  }

  return true;
}

void CommandTracker::processSerialInput() {
  // Copy the input to the buffer.
  uint32_t length = 0;
  extractInput(length);
  if (length >= 50) {
    throwError("Command tracker was overloaded with input commands.");
    return;
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
        Log::reset();
      }
      return;
    }
  }
  
  // Decode the mode.
  uint32_t modeCode;
  uint32_t remainderOffset;
  if (!CommandParsing::parseModeCode(length, modeCode, remainderOffset)) {
    return;
  }
  command.mode = Command::Mode(modeCode);

  // Decode the alphabetic code attribute.
  if (length >= remainderOffset) {
    command.alphaCode = uint32_t(buffer[remainderOffset]);
    remainderOffset += 1;
  }
  if (!CommandParsing::checkAlphaCode(command)) {
    return;
  }
  
  // Decode the remaining attributes.
  uint32_t numAttributes = 0;
  if (length > remainderOffset) {
    bool succeeded = CommandParsing::parseAttributes(
      buffer + remainderOffset, 
      length - remainderOffset, 
      command.attributes,
      numAttributes);
    if (!succeeded) {
      return;
    }
  }
  uint32_t expectedNumAttributes = getExpectedNumAttributes(
    command, numAttributes);
  if (numAttributes != expectedNumAttributes) {
    CommandTracker::bounceError(
      "Unexpected number of attributes.",
      numAttributes,
      expectedNumAttributes);
    return;
  }
  if (!checkAttributes(command)) {
    return;
  }

  // Register the new command.
  lock = true;
  registerCommand(command);
  lock = false;
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

void CommandTracker::bounceError(
  const char *reason,
  int32_t number1,
  int32_t number2
) {
  Command command;
  command.isValid = false;

  // Register the new command.
  lock = true;
  registerCommand(command);
  lock = false;
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
