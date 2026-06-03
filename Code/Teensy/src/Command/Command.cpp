#include "Command.h"

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

bool decodeAttributes(
  const char *stringBuffer,
  uint32_t stringLength,
  int32_t *attributes,
  uint32_t &numAttributes
) {
  numAttributes = 0;

  int32_t accumulator = 0;
  int32_t sign = 1;
  for (uint32_t i = 0; i <= stringLength; ++i) {
    if (stringBuffer[i] == ',' || i == stringLength) {
      int32_t decoded = accumulator * sign;
      attributes[numAttributes] = decoded;
      numAttributes += 1;

      accumulator = 0;
      sign = 1;
      continue;
    }

    if (stringBuffer[i] == '-') {
      if (accumulator != 0 || sign != 1) {
        CommandTracker::throwError(
          "Invalid placement of negative sign", 
          i);
        return false;
      }
      sign = -1;
    } else if (isDigit(stringBuffer[i])) {
      uint8_t digit = uint8_t(stringBuffer[i] - '0');
      accumulator = accumulator * 10 + digit;
    } else {
      CommandTracker::throwError(
        "While decoding attributes, a character was not a digit.", 
        i);
      return false;
    }
  }

  return true;
}

bool validateImageBounds(float X, float Y, float S) {
  float bounds[4] = {
    X - S / 2,
    Y - S / 2,
    X + S / 2,
    Y + S / 2,
  };

  for (uint32_t i = 0; i < 4; ++i) {
    float bound = bounds[i];
    if (bound < -135 || bound > 135) {
      CommandTracker::throwError(
        "Invalid image bounds.",
        int32_t(i),
        int32_t(bound * 10));
      return false;
    }
  }

  return true;
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

  if (numAttributes != expectedNumAttributes) {
    CommandTracker::throwError(
      "Unexpected number of attributes.",
      expectedNumAttributes,
      numAttributes);
    return false;
  }

  // Check the values of the attributes.

  if (command.mode == Command::Mode::simpleScanning) {
    uint32_t frequency = command.attributes[0];
    if (frequency == 0 || frequency > 10000) {
      CommandTracker::throwError(
        "Invalid frequency.",
        frequency);
      return false;
    }

    float peakPeakAmplitude = float(command.attributes[1]) * 0.1;
    if (peakPeakAmplitude <= 0 || peakPeakAmplitude > 270) {
      CommandTracker::throwError(
        "Invalid peak-peak amplitude.",
        int32_t(peakPeakAmplitude * 10));
      return false;
    }
  }

  if (command.mode == Command::Mode::imaging) {
    uint32_t resolution = command.attributes[0];
    if (resolution == 0 || resolution > 1024) {
      CommandTracker::throwError(
        "Invalid resolution.",
        resolution);
      return false;
    }

    float size = float(command.attributes[1]) * 0.1;
    if (size <= 0 || size > 270) {
      CommandTracker::throwError(
        "Invalid size.",
        int32_t(size * 10));
      return false;
    }

    float X = float(command.attributes[2]) * 0.1;
    float Y = float(command.attributes[3]) * 0.1;
    if (!validateImageBounds(X, Y, size)) {
      return false;
    }

    if (command.alphaCode == 'd') {
      float X2 = float(command.attributes[4]) * 0.1;
      float Y2 = float(command.attributes[5]) * 0.1;
      if (!validateImageBounds(X2, Y2, size)) {
        return false;
      }
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
  if (!isDigit(buffer[0])) {
    throwError("First character not digit.");
    return;
  }
  uint8_t modeCode = uint8_t(buffer[0] - '0');
  if (modeCode >= uint8_t(Command::Mode::NUM_MODES)) {
    throwError("Invalid mode code.");
    return;
  }
  command.mode = Command::Mode(modeCode);

  // Decode the alphabetic code attribute.
  if (length >= 2) {
    command.alphaCode = uint32_t(buffer[1]);
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
  } else {
    if (command.alphaCode != 0) {
      throwError("There should be no alpha code.");
      return;
    }
  }

  // Decode the remaining attributes.
  uint32_t numAttributes = 0;
  if (length > 2) {
    bool decodeAttributesWorked = decodeAttributes(
      buffer + 2, 
      length - 2, 
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