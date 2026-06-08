#include "CommandParsing.h"

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

bool parseModeCode(
  uint32_t length,
  uint32_t &modeCode,
  uint32_t &remainderOffset
) {
  remainderOffset = 0;

  if (isDigit(CommandTracker::buffer[0])) {
    remainderOffset += 1;
  } else {
    CommandTracker::throwError("First character not digit.");
    return false;
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
    return false;
  }
  return accumulator;
}

bool CommandParsing::checkAlphaCode(Command command) {
  const char *cString = "";
  if (command.mode == Command::Mode::dacTest) {
    cString = "xyzb";
  } else if (command.mode == Command::Mode::blindStepping) {
    cString = "udc";
  } else if (command.mode == Command::Mode::spectroscopy) {
    cString = "ac";
  } else if (command.mode == Command::Mode::simpleScanning) {
    cString = "xy";
  } else if (command.mode == Command::Mode::imaging) {
    cString = "ivd";
  } else if (command.mode == Command::Mode::imagingSettings) {
    cString = "aclors";
  } else {
    if (command.alphaCode != 0) {
      CommandTracker::throwError("There should be no alpha code.");
      return false;
    }
  }

  for (uint32_t i = 0; i < 50; ++i) {
    if (cString[i] == 0) {
      break;
    }
    if (cString[i] == command.alphaCode) {
      return true;
    }
  }

  CommandTracker::throwError("Invalid alphabetic code.");
  return false;
}

bool CommandParsing::parseAttributes(
  const char *stringBuffer,
  uint32_t stringLength,
  float *attributes,
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