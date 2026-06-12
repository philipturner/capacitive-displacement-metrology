#include "DACTester.h"

#include "Application/Application.h"
#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
#include "Util/WaveUtil.h"
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
  bipolarAmplitude = command.attributes[0];
}

void DACTester::update() {
  uint32_t deltaIters = KilohertzLoop::iterationID;
  uint32_t deltaTime = deltaIters * KilohertzLoop::period;
  uint32_t phase = deltaTime % wavePeriod;

  float phaseNormalized = float(phase) / float(wavePeriod);
  float voltage = WaveUtil::triangleWave(phaseNormalized);
  voltage *= bipolarAmplitude;

  if (channelID == 4) {
    Application::updateBiasVoltage(voltage);
  } else {
    Application::updatePiezoVoltage(channelID, voltage);
  }
}

float DACTester::getActiveChannelVoltage() {
  float voltage = 0;
  if (channelID == 1) {
    voltage = Application::state.piezoXVoltage;
  } else if (channelID == 2) {
    voltage = Application::state.piezoYVoltage;
  } else if (channelID == 3) {
    voltage = Application::state.piezoZVoltage;
  } else if (channelID == 4) {
    voltage = Application::state.biasVoltage;
  }
  return voltage;
}