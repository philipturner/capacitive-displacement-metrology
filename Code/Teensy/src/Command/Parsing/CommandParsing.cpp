#include "CommandParsing.h"

#include "CommandTracker.h"

bool CommandParsing::decodeAttributes(
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