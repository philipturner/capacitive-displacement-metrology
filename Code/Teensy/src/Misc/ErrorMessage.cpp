#include "ErrorMessage.h"

#include <Arduino.h>

void ErrorMessage::reset() {
  errorExists = false;
  cursor = 0;
}

void ErrorMessage::nullTerminate() {
  buffer[cursor] = 0;
}

void ErrorMessage::addNewline() {
  addString("\n");
}

void ErrorMessage::addString(const char* cString) {
  uint32_t inputLength = 512;
  for (uint32_t i = 0; i < 512; ++i) {
    if (cString[i] == 0) {
      inputLength = i;
      break;
    }
  }
  if (inputLength == 512) {
    Serial.println("Could not find null terminator for C string.");
    exit(0);
  }

  for (uint32_t i = 0; i < inputLength; ++i) {
    char character = cString[i];
    buffer[cursor + i] = character;
  }
  cursor += inputLength;
}

void ErrorMessage::addInteger(int32_t x) {
  char buffer[20];
  int32_t returnValue = snprintf(buffer, sizeof(buffer), "%d", x);
  if (returnValue < 0) {
    Serial.println("snprintf failed to encode integer with error code:");
    Serial.println(returnValue);
    exit(0);
  }

  addString(buffer);
}

// snprintf("%.Xf") should work
// https://forum.pjrc.com/index.php?threads/using-double-precision-numbers-in-serial-teensy-3-2-and-4-0.62234/post-248310
void ErrorMessage::addFloat(float x) {
  char buffer[20];
  int32_t returnValue = snprintf(buffer, sizeof(buffer), "%f", x);
  if (returnValue < 0) {
    Serial.println("snprintf failed to encode float with error code:");
    Serial.println(returnValue);
    exit(0);
  }

  addString(buffer);
}