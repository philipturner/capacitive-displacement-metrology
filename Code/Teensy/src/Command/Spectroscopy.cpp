#include "Spectroscopy.h"

#include <Arduino.h>

void Spectroscopy::fillAutoVZPairs() {
  for (uint32_t i = 0; i < 1; ++i) {
    Spectroscopy::VZPair pair;
    pair.voltage = 0.050;
    pair.position = 0e-12;

    autoVZPairs[i] = pair;
  }
}

Spectroscopy::Spectroscopy() {

}

Spectroscopy::Spectroscopy(Command command) {
  if (command.alphaCode == 'a') {
    useCustomVZPair = false;
  } else if (command.alphaCode == 'c') {
    useCustomVZPair = true;
  } else {
    Serial.println("This should never happen.");
    exit(0);
  }

  if (useCustomVZPair) {
    float millivolts = float(command.attributes[0]);
    float picometers = float(command.attributes[1]);
    customVZPair.voltage = millivolts * 1e-3;
    customVZPair.position = picometers * 1e-12;
  }
}