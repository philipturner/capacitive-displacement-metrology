#include "DACTester.h"

#include "Application/Application.h"
#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
#include "Util/FilterUtil.h"
#include <Arduino.h>

uint32_t decodeChannelID(char code) {
  if (code == 'x') {
    return 1;
  } else if (code == 'y') {
    return 2;
  } else if (code == 'z') {
    return 3;
  } else if (code == 'b') {
    return 4;
  } else {
    Serial.println("This should never happen.");
    exit(0);
  }
}

DACTester::DACTester() {

}

DACTester::DACTester(Command command) {
  channelID = decodeChannelID(command.alphaCode);
  bipolarAmplitude = float(command.attributes[0]);
}

void DACTester::update() {
  uint32_t deltaIters = KilohertzLoop::iterationID;
  uint32_t deltaTime = deltaIters * KilohertzLoop::period;
  uint32_t phase = deltaTime % wavePeriod;

  float phaseNormalized = float(phase) / float(wavePeriod);
  float voltage = FilterUtil::triangleWave(phaseNormalized);
  voltage *= bipolarAmplitude;

  // TODO: Finish this.
  if (channelID == 4) {
    
  }
}

void DACTester::reset() {
  
}

void DACTester::writeToLog(uint32_t slotID) {
  float voltage;
  if (channelID == 1) {
    voltage = Application::state.piezoXVoltage;
  } else if (channelID == 2) {
    voltage = Application::state.piezoYVoltage;
  } else if (channelID == 3) {
    voltage = Application::state.piezoZVoltage;
  } else if (channelID == 4) {
    voltage = Application::state.biasVoltage;
  }

  Log::ringBuffers[0][slotID] = Application::state.filteredCurrent;
  Log::ringBuffers[1][slotID] = voltage;
  Log::ringBuffers[2][slotID] = float(channelID);
  Log::ringBuffers[3][slotID] = 0;
}