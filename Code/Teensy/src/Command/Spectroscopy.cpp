#include "Spectroscopy.h"

#include "Application/Application.h"
#include "Diagnostics/Log.h"
#include "Time/KilohertzLoop.h"
#include "Util/Feedback.h"
#include "Util/FilterUtil.h"
#include <Arduino.h>

// Reduce the chance of accidentally crashing the tip because of a typing
// or programming error.
void clampPair(Spectroscopy::VZPair& pair) {
  //pair.voltage = min(pair.voltage, 5.0);
  //pair.voltage = max(pair.voltage, -5.0);

  pair.position = min(pair.position, 10000e-12);
  pair.position = max(pair.position, -10000e-12);
}

// HOPG I(V) spectroscopy
//
// 201 points
// +/-2.0 V, 20 mV resolution, setpoint +50 mV / 10 pA
//
// Cu2O/Cu I(V) spectroscopy
//
// +/-700 mV, 10 mV resolution, setpoint  +50 mV / 10 pA
// +/-1.1 V,  20 mV resolution, setpoint +300 mV / 10 pA
// Going to higher setpoints always results in unstable feedback
//
// HOPG I(z) spectroscopy
//
// 50 pm resolution, 121 points
// +50 mV / 10 pA: [-2000, 4000] pm
void Spectroscopy::fillAutoVZPairs() {
  #if 0
  for (uint32_t i = 0; i <= 6000; i += 50) {
    Spectroscopy::VZPair pair;
    pair.voltage = 0.050;
    pair.position = (float(i) - 2000) * 1e-12;
    clampPair(pair);

    autoVZPairs[i / 50] = pair;
  }
  #else
  for (uint32_t i = 0; i <= 4000; i += 20) {
    Spectroscopy::VZPair pair;
    pair.voltage = (float(i) - 2000) * 1e-3;
    pair.position = 0;
    clampPair(pair);

    autoVZPairs[i / 20] = pair;
  }
  #endif

  //  autoVZPairs[0] = { 0, 0 };
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
    customVZPair.voltage = millivolts * 1e-3;

    float picometers = float(command.attributes[1]);
    customVZPair.position = picometers * 1e-12;
    
    clampPair(customVZPair);
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

  Log::writeValues(
    /*lane0=*/pair.voltage,
    /*lane1=*/pair.position * 1e12,
    /*lane2=*/result.accumulators[0] * 1e12,
    /*lane3=*/result.accumulators[1] * 1e12,
    /*lane4=*/result.accumulators[2] * 1e12,
    /*flags=*/0b10);
  
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

void Spectroscopy::accumulate(uint32_t index) {
  float current = Application::state.filteredCurrent;
  pendingResult1.accumulators[index] += log(abs(current));
  pendingResult1.sampleCount[index] += 1;
  pendingResult1.signBallot[index] += (current > 0) ? 1 : -1;
  pendingResult2.accumulators[index] += log(abs(current));
  pendingResult2.sampleCount[index] += 1;
  pendingResult2.signBallot[index] += (current > 0) ? 1 : -1;
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

float Spectroscopy::getPiezoZVoltage(float progress) {
  auto pair = getCurrentVZPair();
  float dV = pair.position / 0.320e-9;

  float start = restPiezoZVoltage;
  float end = start + dV;
  
  float output = linearInterpolate(start, end, progress);
  output = min(output, 270);
  output = max(output, -80);
  return output;
}

void Spectroscopy::update() {
  updateState();

  if (pairID >= getPairCount()) {
    Application::updateBiasVoltage(Feedback::setpointVoltage);
    Feedback::updatePiezoZ();
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

    // 1471 Hz resonance
    // below 2000 μs rise time, a simple line is optimal
    // above 2000 μs rise time, a 3rd-order smoothstep attenuates overshoot better
    positionProgress = FilterUtil::thirdOrderSmoothstep(positionProgress);

    float biasVoltage = getBiasVoltage(voltageProgress);
    float piezoZVoltage = getPiezoZVoltage(positionProgress);
    float triggerSignal = (i == 0) ? float(2) : float(-2);
    
    if (time < positionSettlePeriod) {
      Application::updateBiasVoltage(biasVoltage);
      Application::updatePiezoVoltage(3, piezoZVoltage);
      Application::state.positionError = triggerSignal;
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
  Feedback::updatePiezoZ();
}
