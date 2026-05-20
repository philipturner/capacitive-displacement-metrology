#include "PA95.h"

#include "DAC.h"
#include <Arduino.h>

void PA95::writeVoltage(uint8_t channelID, float voltage) {
  uint8_t dacChannel = 0;
  float gain = 0;
  float offset = 0;

  if (channelID == 1) {
    dacChannel = 1;
    gain = -35.690;
    offset = 0.093;
  } else if (channelID == 2) {
    dacChannel = 3;
    gain = -35.699;
    offset = -0.036;
  } else if (channelID == 3) {
    dacChannel = 2;
    gain = -35.699;
    offset = -0.022;
  } else {
    Serial.println("Invalid PA95 channel.");
    exit(0);
  }

  float dacValue = (voltage - offset) / gain;
  DAC1::writeVoltage(dacChannel, dacValue);
}