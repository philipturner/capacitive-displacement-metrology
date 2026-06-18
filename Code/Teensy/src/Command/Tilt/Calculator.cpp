#include "Calculator.h"

#include "Application/Application.h"
#include "Command/Tilt/Settings.h"
#include "Diagnostics/Log.h"
#include <Arduino.h>

using namespace Tilt;

uint32_t getTrialsPerResult(float reportPeriodSeconds, uint32_t trialTime) {
  float reportPeriodMicros = reportPeriodSeconds * 1e6;
  float output = reportPeriodMicros / float(trialTime);
  output = ceil(output);
  output = max(output, 0);
  return uint32_t(output);
}

Calculator::Calculator() {

}

Calculator::Calculator(Command command) {
  if (command.alphaCode != 'c') {
    Serial.println("This should never happen.");
    exit(0);
  }

  displacementSize = command.attributes[0];
  movementTime = uint32_t(command.attributes[1] * 1000);
  movementTime = KilohertzLoopRound(movementTime);
  trialsPerResult = getTrialsPerResult(reportPeriodSeconds, getTimePerTrial());
}

void Calculator::update() {
  uint32_t time = Application::state.getTimeSinceModeStart();
  uint32_t trialTime = getTimePerTrial();
  uint32_t resultTime = trialsPerResult * trialTime;
  uint32_t resultID = time / resultTime;
  uint32_t timeInResult = time % resultTime;
  uint32_t timeInTrial = timeInResult % trialTime;

  if (timeInTrial == 0 && time > 0) {
    float2 dz = pendingTrial.getDifference();
    float dxy = displacementSize / 0.320;
    float2 slope = dz / dxy;

    pendingResult.update(slope);
    pendingTrial = Trial();
  }

  if (timeInResult == 0 && resultID > 0) {
    float2 avg = pendingResult.mean;
    float2 stddev = pendingResult.getStddev();
    Log::writeValuesWithFlags(
      9, // flags
      avg.x,
      avg.y,
      stddev.x,
      stddev.y,
      pendingResult.count);
    
    pendingResult = Result();
  }

  Application::correctZVoltage();
}

uint32_t Calculator::getTimePerTrial() {
  uint32_t output = 0;
  output += paddingTime;
  output += 2 * (movementTime + settleTime + paddingTime);
  output *= 2;
  return output;
}

void Calculator::updateForTrial(uint32_t timeInTrial) {
  uint32_t time = timeInTrial;

  for (uint32_t axisID = 0; axisID < 2; ++axisID) {
    if (time < paddingTime) {
      pendingTrial.start[axisID] = Application::state.piezoZVoltage;
      return;
    } else {
      time -= paddingTime;
    }

    for (uint32_t i = 0; i < 2; ++i) {
      if (time <= movementTime + settleTime) {
        float progress = float(time) / float(movementTime);
        progress = min(progress, 1);
        if (i == 1) {
          progress = 1 - progress;
        }

        float position = displacementSize * progress;
        float voltage = position / 0.320;
        uint32_t channelID = 1 + axisID;
        Application::updatePiezoVoltage(channelID, voltage);
        return;
      } else {
        time -= movementTime + settleTime;
      }

      if (time < paddingTime) {
        float voltageZ = Application::state.piezoZVoltage;
        if (i == 0) {
          pendingTrial.middle[axisID] = voltageZ;
        } else {
          pendingTrial.end[axisID] = voltageZ;
        }
        return;
      } else {
        time -= paddingTime;
      }
    }
  }

  Serial.println("This should never happen.");
  exit(0);
}