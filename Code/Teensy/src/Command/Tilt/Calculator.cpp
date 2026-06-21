#include "Calculator.h"

#include "Application/Application.h"
#include "Command/Tilt/Settings.h"
#include "Diagnostics/Log.h"
#include "IC/DAC.h"
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
  displacementSize = command.attributes[0];
  originScannerVoltage = getOriginScannerVoltage(command);

  movementTime = uint32_t(command.attributes[1] * 1000);
  movementTime = KilohertzLoopRound(movementTime);
  trialsPerResult = 36;
}

float2 Calculator::getOriginScannerVoltage(Command command) {
  float2 position;
  if (command.alphaCode == 'c') {
    position = float2(0);
  } else if (command.alphaCode == 'o') {
    position = float2(
      command.attributes[2],
      command.attributes[3]);
  } else {
    Serial.println("Invalid alpha code.");
    exit(0);
  }

  return position / 0.320f;
}

void Calculator::update() {
  uint32_t time = Application::state.getTimeSinceModeStart();
  uint32_t trialTime = getTimePerTrial();
  uint32_t resultTime = trialsPerResult * trialTime;
  uint32_t timeInResult = time % resultTime;
  uint32_t trialID = timeInResult / trialTime;
  uint32_t timeInTrial = timeInResult % trialTime;

  if (!isFinished) {
    if (timeInTrial == 0 && time > 0) {
      float2 dz = pendingTrial.getDifference();
      float2 slope = dz / displacementSize;
      
      pendingResult.update(slope);
      pendingTrial = Trial();
    }

    if (timeInResult == 0 && time > 0) {
      float2 avg = pendingResult.mean;
      float2 stddev = pendingResult.getStddev();
      Log::write(
        Log::Flags::tiltCalculation,
        avg.x,
        avg.y,
        stddev.x,
        stddev.y,
        pendingResult.count);
      
      pendingResult = Result();

      if (time > stopTime) {
        isFinished = true;
      }
    }

    updateForTrial(timeInTrial, trialID);
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

void Calculator::updateForTrial(uint32_t timeInTrial, uint32_t trialID) {
  uint32_t time = timeInTrial;
  float z = Application::state.piezoZVoltage * 0.320f;

  for (uint32_t axisID = 0; axisID < 2; ++axisID) {
    if (time < paddingTime) {
      pendingTrial.start[axisID] = z;
      return;
    } else {
      time -= paddingTime;
    }

    uint32_t loopTime = movementTime + settleTime + paddingTime;
    if (time >= 2 * loopTime) {
      time -= 2 * loopTime;
      continue;
    }

    uint32_t i = 0;
    if (time >= loopTime) {
      time -= loopTime;
      i = 1;
    }

    float progress = float(time) / float(movementTime);
    progress = min(progress, 1);
    if (i == 1) {
      progress = 1 - progress;
    }

    float dl = displacementSize * progress;
    float2 dxy = float2(0);
    if (axisID == 0) {
      dxy.x = dl;
    } else {
      dxy.y = dl;
    }
    
    if (time == 0 && i == 1) {
      // Best settings: 11c10,50
      Serial.print(trialID);
      Serial.print(" ");
      Serial.print(axisID);
      Serial.print(" ");
      Serial.print(dxy.x);
      Serial.print(" ");
      Serial.print(dxy.y);
      Serial.print(" ");
      Serial.print(z);
      Serial.print(" ");
      Serial.println();
    }

    float2 scannerVoltage = dxy / 0.320f;
    scannerVoltage += originScannerVoltage;
    
    if (time <= movementTime + settleTime) {
      Application::updatePiezoVoltage(1, scannerVoltage.x);
      DAC::enableSafeWait = false;
      Application::updatePiezoVoltage(2, scannerVoltage.y);
      DAC::enableSafeWait = true;
    } else {
      if (i == 0) {
        pendingTrial.middle[axisID] = z;
      } else {
        pendingTrial.end[axisID] = z;
      }
    }

    return;
  }

  Serial.println("This should never happen.");
  exit(0);
}