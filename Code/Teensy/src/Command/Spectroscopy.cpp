#include "Spectroscopy.h"

#include "Application/Application.h"
#include "Diagnostics/Log.h"
#include "Filter/Feedback.h"
#include "Time/KilohertzLoop.h"
#include "Util/Interpolate.h"
#include "Util/WaveUtil.h"
#include <Arduino.h>

// HOPG I(V) spectroscopy
//
// 201 points
// +/-2.0 V, 20 mV resolution, setpoint +50 mV / 10 pA
// +/-2.0 V, 20 mV resolution, setpoint +1.0 V / 1 nA
//
// Cu2O/Cu I(V) spectroscopy
//
// 141 points
// +/-700 mV, 10 mV resolution, setpoint  +50 mV / 10 pA
// 111 points
// +/-1.1 V,  20 mV resolution, setpoint +300 mV / 10 pA
// Going to higher setpoints always results in unstable feedback
//
// HOPG I(z) spectroscopy
//
// 50 pm resolution, 121 points
// +50 mV / 10 pA: [-2000, 4000] pm
// +1.0 V / 1 nA:  [-6000, 0] pm
void Spectroscopy::fillAutoVZPairs() {
  // add code here
}

Spectroscopy::Spectroscopy() {

}

Spectroscopy::Spectroscopy(Command command) {
  if (command.alphaCode == 'a') {
    useCustomVZPair = false;
    autoScaleFactor = command.attributes[0];
  } else if (command.alphaCode == 'c') {
    useCustomVZPair = true;
    customVZPair.voltage = command.attributes[0] * 1e-3;
    customVZPair.position = command.attributes[1] * 1e-12;
  } else {
    Serial.println("This should never happen.");
    exit(0);
  }
  
  trialStartIterationID = KilohertzLoop::iterationID;
}

void Spectroscopy::update() {
  updateState();

  if (shouldUpdateForTrial()) {
    updateForTrial();
  } else {
    Application::setBiasForFeedback();
    Application::correctZVoltage();
  }
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
  output += delayBeforeFeedback;
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
    VZPair output = autoVZPairs[pairID];
    if (autoTypeIsPosition) {
      output.position *= autoScaleFactor;
    } else {
      output.voltage *= autoScaleFactor;
    }
    return output;
  }
}

void Spectroscopy::pushResult(uint32_t sampleCount, Result& result) {
  auto pair = getCurrentVZPair();

  for (uint32_t i = 0; i < 3; ++i) {
    if (result.sampleCount[i] != sampleCount) {
      Serial.println("Incorrect sample count.");
      exit(0);
    }

    float output = result.accumulators[i];
    output *= 1 / float(sampleCount);
    output = exp(output);
    if (result.signBallot[i] == 0) {
      output = 0;
    } else if (result.signBallot[i] < 0) {
      output = -output;
    }
    result.accumulators[i] = output;
  }

  Log::writeValuesWithFlags(
    2, // flags
    pair.voltage,
    pair.position * 1e12,
    result.accumulators[0] * 1e12,
    result.accumulators[1] * 1e12,
    result.accumulators[2] * 1e12);
  
  result = Result();
}

void Spectroscopy::updateState() {
  if (pairID >= getPairCount()) {
    return;
  }

  uint32_t timePerTrial = getTimePerTrial();
  uint32_t currentTime = getTimeSinceTrialStart();

  if (currentTime >= timePerTrial) {
    // uint32_t sampleCount = integratePeriod / KilohertzLoop::period;
    // pushResult(sampleCount, pendingResult1);

    trialID += 1;
    trialStartIterationID = KilohertzLoop::iterationID;
    restPiezoZVoltage = -270;
  }

  if (trialID >= trialsPerResult) {
    uint32_t sampleCount = integratePeriod / KilohertzLoop::period;
    sampleCount *= trialsPerResult;
    pushResult(sampleCount, pendingResult2);

    trialID = 0;
    pairID += 1;
  }
}

bool Spectroscopy::shouldUpdateForTrial() {
  if (pairID >= getPairCount()) {
    return false;
  }

  uint32_t time = getTimeSinceTrialStart();
  uint32_t maxTime = getTimePerTrial() - feedbackTime;
  if (time < maxTime) {
    return true;
  } else {
    return false;
  }
}

void Spectroscopy::updateForTrial() {
  uint32_t time = getTimeSinceTrialStart();
  if (time < integratePeriod) {
    accumulate(0);

    if (time == 0) {
      Application::setBiasForFeedback();
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

    // 1471 Hz resonance
    // below 2000 μs rise time, a simple line is optimal
    // above 2000 μs rise time, a 3rd-order smoothstep attenuates overshoot better
    positionProgress = WaveUtil::thirdOrderSmoothstep(positionProgress);

    float biasVoltage = getBiasVoltage(voltageProgress);
    float piezoZVoltage = getPiezoZVoltage(positionProgress);
    float triggerSignal = (i == 0) ? float(2) : float(-2);
    
    if (time < positionSettlePeriod) {
      Application::updateBiasVoltage(biasVoltage);
      Application::updatePiezoVoltage(3, piezoZVoltage);
      Application::state.spectroscopyTrigger = triggerSignal;
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

  if (time < delayBeforeFeedback) {
    return;
  } else {
    Serial.println("This should never happen.");
    exit(0);
  }
}

void Spectroscopy::accumulate(uint32_t index) {
  float current = Application::state.filteredCurrent;
  pendingResult1.accumulators[index] += log(abs(current));
  pendingResult1.sampleCount[index] += 1;
  pendingResult1.signBallot[index] += (current > 0) ? 1 : -1;
  pendingResult2.accumulators[index] += log(abs(current));
  pendingResult2.sampleCount[index] += 1;
  pendingResult2.signBallot[index] += (current > 0) ? 1 : -1;
}

float Spectroscopy::getBiasVoltage(float progress) {
  auto pair = getCurrentVZPair();

  float start = Feedback::setpointVoltage;
  float end = pair.voltage;
  return interpolate(start, end, progress);
}

float Spectroscopy::getPiezoZVoltage(float progress) {
  auto pair = getCurrentVZPair();
  float dV = pair.position / 0.320e-9;

  float start = restPiezoZVoltage;
  float end = start + dV;
  
  float output = interpolate(start, end, progress);
  output = min(output, 270);
  output = max(output, -80);
  return output;
}