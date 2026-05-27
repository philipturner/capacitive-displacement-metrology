#include "Spectroscopy.h"

#include "Application/Application.h"
#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
#include "Util/Feedback.h"
#include "Util/FilterUtil.h"
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
    float n = float(integratePeriod) / float(KilohertzLoop::period);

    Log::writeValues(
      /*lane0=*/pair.voltage,
      /*lane1=*/pair.position * 1e12,
      /*lane2=*/result.accumulators[0] / n * 1e12,
      /*lane3=*/result.accumulators[1] / n * 1e12,
      /*lane4=*/result.accumulators[2] / n * 1e12,
      /*flags=*/0b10);
    
    trialID = 0;
    resultID += 1;
    pendingResult = Result();
  }
}

void Spectroscopy::accumulate(uint32_t index) {
  float current = Application::state.filteredCurrent;
  pendingResult.accumulators[index] += current;
}

float Spectroscopy::getBiasVoltage(float progress) {
  auto pair = getCurrentVZPair();
}

void Spectroscopy::update() {
  if (resultID >= getResultCount()) {
    Application::updateBiasVoltage(Feedback::setpointVoltage);
    Feedback::updatePiezoZ();
    return;
  }

  int32_t time = getTimeSinceTrialStart();
  if (time < integratePeriod) {
    accumulate(0);

    if (Application::state.biasVoltage != Feedback::setpointVoltage) {
      Application::updateBiasVoltage(Feedback::setpointVoltage);
    }
    restPiezoZVoltage = Application::state.piezoZVoltage;
    return;
  } else {
    time -= integratePeriod;
  }

  for (uint32_t i = 0; i < 2; ++i) {
    if (time < 0) {
      Serial.println("This should never happen.");
      exit(0);
    }

    float voltageProgress = float(time) / float(voltageSlewPeriod);
    float positionProgress = float(time) / float(positionSettlePeriod);
    voltageProgress = min(voltageProgress, 1);
    positionProgress = min(positionProgress, 1);
    if (i == 1) {
      voltageProgress = 1 - voltageProgress;
      positionProgress = 1 - positionProgress;
    }


    if (time < positionSettlePeriod) {
      return;
    } else {
      time -= positionSettlePeriod;
    }

    if (time < integratePeriod) {
      // do something
      return;
    } else {
      time -= integratePeriod;
    }
  }

  Application::updateBiasVoltage(Feedback::setpointVoltage);
  Feedback::updatePiezoZ();
}