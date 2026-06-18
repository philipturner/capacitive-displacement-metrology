#include "Feedback.h"

#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include "Util/WaveUtil.h"
#include <Arduino.h>

float getFeedbackErrorTerm() {
  float expectedCurrent = abs(Feedback::setpointCurrent);
  if (Feedback::setpointVoltage < 0) {
    expectedCurrent = -expectedCurrent;
  }

  float x = Application::state.current / expectedCurrent;
  x = max(x, -0.5); // cleanly average -5 pA noise band when setpoint is 10 pA

  float k = 1.025e10 * sqrt(Feedback::tunnelingBarrierHeight);
  float kΔz = x - 1;

  // Make it even more repulsive at high currents.
  float F = exp(k * 50e-12);
  if (x > F) {
    kΔz += (x - F) * (x - F);
  }
  return kΔz / k;
}

float Feedback::getVoltageCorrection() {
  float dz = getFeedbackErrorTerm();
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
  float correctionInVolts = correctionInMeters / 0.320e-9;

  // TODO: Calculate tilt correction.

  // Limit slew rate to 0.5 V/μs.
  float maxVoltageChange = 0.5 * float(KilohertzLoop::period);
  correctionInVolts = max(correctionInVolts, -maxVoltageChange);
  correctionInVolts = min(correctionInVolts, maxVoltageChange);

  float voltage = Application::state.piezoZVoltage;
  voltage += correctionInVolts;
  voltage = min(voltage, 270);
  voltage = max(voltage, -80);
  return voltage;
}