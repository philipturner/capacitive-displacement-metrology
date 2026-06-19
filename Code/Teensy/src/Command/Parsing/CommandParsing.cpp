#include "CommandParsing.h"

#include <Arduino.h>

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

bool CommandParsing::parseModeCode(
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
  modeCode = accumulator;

  return true;
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
    cString = "aflors";
  } else if (command.mode == Command::Mode::creepSettings) {
    cString = "crxy";
  } else if (command.mode == Command::Mode::tilt) {
    cString = "ct";
  } else {
    if (command.alphaCode != 0) {
      CommandTracker::throwError("There should be no alpha code.");
      return false;
    }
    return true;
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

struct NumberAccumulator {
  uint32_t wholePart = 0;
  uint32_t decimalNumerator = 0;
  uint32_t decimalDenominator = 1;
  bool signSeen = false;
  bool decimalSeen = false;
  bool digitSeen = false;
};

bool CommandParsing::parseAttributes(
  const char *stringBuffer,
  uint32_t stringLength,
  float *attributes,
  uint32_t &numAttributes
) {
  numAttributes = 0;

  NumberAccumulator number;

  for (uint32_t i = 0; i <= stringLength; ++i) {
    if (stringBuffer[i] == ',' || i == stringLength) {
      if (!number.digitSeen) {
        CommandTracker::throwError("No digits in number.");
        return false;
      }

      float fraction = number.decimalNumerator;
      fraction /= float(number.decimalDenominator);
      if (fraction < -1 || fraction > 1) {
        CommandTracker::throwError("Failed to decode fraction correctly.");
        return false;
      }

      float decoded = float(number.wholePart) + fraction;
      if (number.signSeen) {
        decoded = -decoded;
      }

      attributes[numAttributes] = decoded;
      numAttributes += 1;
      number = NumberAccumulator();
      continue;
    }

    if (stringBuffer[i] == '-') {
      if (number.signSeen || number.decimalSeen || number.digitSeen) {
        CommandTracker::throwError("Invalid sign.");
        return false;
      }
      number.signSeen = true;
    } else if (stringBuffer[i] == '.') {
      if (number.decimalSeen) {
        CommandTracker::throwError("Invalid decimal.");
        return false;
      }
      number.decimalSeen = true;
    } else if (isDigit(stringBuffer[i])) {
      uint8_t digit = stringBuffer[i] - '0';
      if (number.decimalSeen) {
        number.decimalNumerator = number.decimalNumerator * 10 + digit;
        number.decimalDenominator *= 10;
      } else {
        number.wholePart = number.wholePart * 10 + digit;
      }
      number.digitSeen = true;
    } else {
      CommandTracker::throwError(
        "Unexpected character type.", i, stringBuffer[i]);
      return false;
    }
  }

  return true;
}