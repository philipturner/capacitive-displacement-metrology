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

uint32_t Spectroscopy::getPairCount() {
  if (useCustomVZPair) {
    return 1;
  } else {
    return numAutoVZPairs;
  }
}

Spectroscopy::VZPair Spectroscopy::getCurrentVZPair() {
  if (useCustomVZPair) {
    return customVZPair;
  } else {
    return autoVZPairs[pairID];
  }
}

void Spectroscopy::pushResult(uint32_t sampleCount) {
  auto pair = getCurrentVZPair();
  auto result = pendingResult;

  for (uint32_t i = 0; i < 3; ++i) {
    result.accumulators[i] *= 1 / float(sampleCount);

    if (result.sampleCount[i] != sampleCount) {
      Serial.println("Incorrect sample count.");
      exit(0);
    }
  }

  Log::writeValues(
    /*lane0=*/pair.voltage,
    /*lane1=*/pair.position * 1e12,
    /*lane2=*/result.accumulators[0] * 1e12,
    /*lane3=*/result.accumulators[1] * 1e12,
    /*lane4=*/result.accumulators[2] * 1e12,
    /*flags=*/0b10);
  
  pendingResult = Result();
}

void Spectroscopy::updateState() {
  if (pairID >= getPairCount()) {
    return;
  }

  uint32_t timePerTrial = getTimePerTrial();
  uint32_t currentTime = getTimeSinceTrialStart();

  if (currentTime >= timePerTrial) {
    uint32_t sampleCount = integratePeriod / KilohertzLoop::period;
    pushResult(sampleCount);

    trialID += 1;
    trialStartIterationID = KilohertzLoop::iterationID;
    restPiezoZVoltage = -270;
  }

  if (trialID >= trialsPerResult) {
    trialID = 0;
    pairID += 1;
  }
}

void Spectroscopy::accumulate(uint32_t index) {
  float current = Application::state.filteredCurrent;

  // Checking basic operation of the new code.
  if (index == 1) {
    current = float(pendingResult.sampleCount[index]);
  }

  pendingResult.accumulators[index] += current;
  pendingResult.sampleCount[index] += 1;
}

float linearInterpolate(float start, float end, float t) {
  float output = 0;
  output += start * (1 - t);
  output += end * t;
  return output;
}

float Spectroscopy::getBiasVoltage(float progress) {
  auto pair = getCurrentVZPair();

  float start = Feedback::setpointVoltage;
  float end = pair.voltage;
  return linearInterpolate(start, end, progress);
}

float Spectroscopy::getPiezoZVoltage(float unsmoothedProgress) {
  auto pair = getCurrentVZPair();
  float dV = pair.position / 0.320e-9;

  float start = restPiezoZVoltage;
  float end = start + dV;
  float progress = FilterUtil::thirdOrderSmoothstep(unsmoothedProgress);
  
  float output = linearInterpolate(start, end, progress);
  output = min(output, 270);
  output = max(output, -130);
  return output;
}

/*
-0.049999237, 400.0, 0.3641281, 2.0499879e+13, -0.028001785, 
-0.049999237, 400.0, 0.40020752, 2.0499879e+13, -0.12823105, 
-0.049999237, 400.0, -0.13733292, 2.0499879e+13, -0.118494034, 
-0.049999237, 400.0, 0.64756775, 2.0499879e+13, -0.24730301, 
-0.049999237, 400.0, 0.57629395, 2.0499879e+13, -0.21464157, 
-0.049999237, 400.0, 0.31822205, 2.0499879e+13, -0.2422638, 
-0.049999237, 400.0, -0.32456207, 2.0499879e+13, -0.39032745, 
-0.049999237, 400.0, -0.08976364, 2.0499879e+13, -0.31079102, 
-0.049999237, 400.0, 0.22520828, 2.0499879e+13, -0.20956802, 
-0.049999237, 400.0, 0.251503, 2.0499879e+13, 0.103227615, 
*/

void Spectroscopy::update() {
  updateState();

  if (pairID >= getPairCount()) {
    Application::updateBiasVoltage(Feedback::setpointVoltage);
    //Feedback::updatePiezoZ();
    return;
  }

  uint32_t time = getTimeSinceTrialStart();
  if (time < integratePeriod) {
    accumulate(0);

    if (time == 0) {
      Application::updateBiasVoltage(Feedback::setpointVoltage);
    }
    restPiezoZVoltage = Application::state.piezoZVoltage;
    return;
  } else {
    time -= integratePeriod;
  }

  for (uint32_t i = 0; i < 2; ++i) {
    if (int32_t(time) < 0) {
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

    float biasVoltage = getBiasVoltage(voltageProgress);
    float piezoZVoltage = getPiezoZVoltage(positionProgress);
    
    if (time < positionSettlePeriod) {
      Application::updateBiasVoltage(biasVoltage);
      Application::updatePiezoVoltage(3, piezoZVoltage);
      return;
    } else {
      time -= positionSettlePeriod;
    }

    if (time < integratePeriod) {
      if (time == 0) {
        Application::updateBiasVoltage(biasVoltage);
        Application::updatePiezoVoltage(3, piezoZVoltage);
      }
      accumulate(1 + i);
      return;
    } else {
      time -= integratePeriod;
    }
  }

  Application::updateBiasVoltage(Feedback::setpointVoltage);
  //Feedback::updatePiezoZ();
}
