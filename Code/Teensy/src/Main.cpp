#include "Misc/Application.h"
#include "Misc/ErrorMessage.h"
#include <Arduino.h>

// First thing to do: test error message construction.

void setup() {
  Application::setupSerial();

  for (uint32_t i = 0; i < 2; ++i) {
    ErrorMessage::errorExists = true;
    ErrorMessage::addString("a string: ");
    ErrorMessage::addInteger(-42);
    ErrorMessage::addNewline();
    ErrorMessage::addString("another s");
    ErrorMessage::addString("tring: ");
    ErrorMessage::addFloat(5.9e-9);
    ErrorMessage::addString(" ");
    ErrorMessage::addFloat(float(micros()) / 1000);

    if (ErrorMessage::errorExists) {
      ErrorMessage::nullTerminate();
      Serial.println("error message:");
      Serial.println(ErrorMessage::buffer);
    }

    ErrorMessage::reset();

    if (ErrorMessage::errorExists) {
      ErrorMessage::nullTerminate();
      Serial.println("error message:");
      Serial.println(ErrorMessage::buffer);
    }
  }
}

void loop() {

}