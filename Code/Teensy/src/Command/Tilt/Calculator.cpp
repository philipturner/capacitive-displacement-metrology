#include "Calculator.h"

#include "Application/Application.h"
#include "Command/Tilt/Settings.h"
#include <Arduino.h>

using namespace Tilt;

Calculator::Calculator() {

}

Calculator::Calculator(Command command) {
  if (command.alphaCode != 'c') {
    Serial.println("This should never happen.");
    exit(0);
  }

  displacement = command.attributes[1];
}

void Calculator::update() {
  uint32_t time = Application::state.getTimeSinceModeStart();
  
  Application::correctZVoltage();
}