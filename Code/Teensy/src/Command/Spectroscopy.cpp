#include "Spectroscopy.h"

#include "Application/Application.h"
#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
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

  trialStartIterationID = KilohertzLoop::iterationID;
}

uint32_t Spectroscopy::getTimeSinceTrialStart() {
  uint32_t deltaIters = KilohertzLoop::iterationID;
  deltaIters -= trialStartIterationID;
  return deltaIters * KilohertzLoop::period;
}

uint32_t Spectroscopy::getTimePerTrial() {
  uint32_t output = 0;
  output += integratePeriod;
  output += 2 * (positionSettlePeriod + integratePeriod);
  output += feedbackTime;
  return output;
}

uint32_t Spectroscopy::getResultCount() {
  if (useCustomVZPair) {
    return 1;
  } else {
    return numAutoVZPairs;
  }
}

Spectroscopy::VZPair
Spectroscopy::getCurrentVZPair() {
  if (useCustomVZPair) {
    return customVZPair;
  } else {
    return autoVZPairs[resultID];
  }
}

void Spectroscopy::updateState() {
  if (resultID >= getResultCount()) {
    return;
  }

  uint32_t timePerTrial = getTimePerTrial();
  uint32_t currentTime = getTimeSinceTrialStart();

  if (currentTime >= timePerTrial) {
    trialID += 1;
    trialStartIterationID = KilohertzLoop::iterationID;
  }

  if (trialID >= trialsPerResult) {
    auto pair = getCurrentVZPair();
    auto result = pendingResult;
    float n = float(result.sampleCount);
    
    Log::writeValues(
      /*lane0=*/pair.voltage,
      /*lane1=*/pair.position,
      /*lane2=*/result.accumulatorBefore / n,
      /*lane3=*/result.accumulatorDuring / n,
      /*lane4=*/result.accumulatorAfter / n,
      /*flags=*/0b10);
    
    trialID = 0;
    resultID += 1;
    pendingResult = Result();
  }
}