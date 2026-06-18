#include "Feedback.h"

#include "Time/KilohertzLoop.h"
#include "Util/WaveUtil.h"
#include <Arduino.h>

float getFeedbackErrorTerm(float current) {
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
  float F = expf(k * 50e-12f);
  if (ratio > F) {
    kΔz += (ratio - F) * (ratio - F);
  }
  return kΔz / k;
}

float Feedback::getVoltageCorrection(float current) {
  float dz = getFeedbackErrorTerm(current);
  if (useNotchFilter) {
    notchFilter.update(dz);
    dz = notchFilter.getOutput();
  }
  
  // v_max = 2 π f_0 A_max
  // v_max = 2 π 1470 Hz * 50e-12 m
  // v_max = 462 nm/s
  // Δx = vΔt = (462 nm/s) * (20 μs)
  // Δx = 9.2e-12 m
  //
  // max dz registered: 
  // -1 / (1.025e10 * sqrt(barrier height)) = -98 pm
  // -(-98 pm) * 20e-6 / 500e-6 = 3.9 pm
  // enforcing a limit on approach speed will not change anything
  float timeProgress = float(KilohertzLoop::period) / float(integratorTimeLag);
  float correctionInMeters = -dz * timeProgress;
  float correctionInVolts = correctionInMeters / 0.320e-9f;

  // Limit slew rate to 0.5 V/μs.
  float maxVoltageChange = 0.5f * float(KilohertzLoop::period);
  correctionInVolts = max(correctionInVolts, -maxVoltageChange);
  correctionInVolts = min(correctionInVolts, maxVoltageChange);
  return correctionInVolts;
}