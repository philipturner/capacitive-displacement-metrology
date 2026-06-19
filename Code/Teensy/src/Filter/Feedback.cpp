#include "Feedback.h"

#include "Time/KilohertzLoop.h"
#include "Util/WaveUtil.h"
#include <Arduino.h>

float2 getFeedbackErrorTerm(float current) {
  float expectedCurrent;
  if (Feedback::setpointVoltage >= 0) {
    expectedCurrent = Feedback::setpointCurrent;
  } else {
    expectedCurrent = -Feedback::setpointCurrent;
  }

  // Cleanly average -5 pA noise band when setpoint is 10 pA
  float clampedCurrent;
  if (Feedback::setpointVoltage >= 0) {
    clampedCurrent = max(current, -5e-12f);
  } else {
    clampedCurrent = min(current, 5e-12f);
  }

  float ratio = clampedCurrent / expectedCurrent;
  float k = 1.025e10f * sqrtf(Feedback::tunnelingBarrierHeight);
  float kΔz = ratio - 1.0f;

  // Make it even more repulsive at high currents.
  float F = 2.0;
  float extraRepulsivePart = 0;
  if (ratio > F) {
    extraRepulsivePart = (ratio - F) * (ratio - F);
  }

  float2 output(kΔz, extraRepulsivePart);
  output /= k;
  return output;
}

float Feedback::getVoltageCorrection(float current) {
  float2 components = getFeedbackErrorTerm(current);
  notchFilter.update(components.x);
  components.x = notchFilter.getOutput();

  float slowProgress = float(KilohertzLoop::period) / float(timeConstant);
  float fastProgress = float(KilohertzLoop::period) / float(defaultTimeConstant);
  float slowed_dz = components.x * slowProgress + components.y * fastProgress;
  
  float correctionInVolts = -slowed_dz / 0.320e-9f;

  // Limit slew rate to 0.5 V/μs.
  float maxVoltageChange = 0.5f * float(KilohertzLoop::period);
  correctionInVolts = max(correctionInVolts, -maxVoltageChange);
  correctionInVolts = min(correctionInVolts, maxVoltageChange);
  return correctionInVolts;
}