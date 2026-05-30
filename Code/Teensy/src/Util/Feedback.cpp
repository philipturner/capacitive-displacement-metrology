#include "Feedback.h"

#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include <Arduino.h>

void updatePositionErrorDiagnostic() {
  float current = Application::state.filteredCurrent;
  if (Feedback::setpointVoltage < 0) {
    current = -current;
  }
  current = max(current, 2e-12);
  float dlnI = log(current / Feedback::setpointCurrent);

  // Position error in meters. Positive means you're too close, correct it
  // by moving backward (more negative voltage).
  float dlnI_dz = 1.025e10 * sqrt(Feedback::tunnelingBarrierHeight);
  float dz = dlnI / dlnI_dz;
  Application::state.positionError = dz;
}

// https://www.desmos.com/calculator/jd4kbteajk
//
// F makes it jump backward too much on Cu2O/Cu
float getFeedbackErrorTerm() {
  float expectedCurrent = abs(Feedback::setpointCurrent);
  if (Feedback::setpointVoltage < 0) {
    expectedCurrent = -expectedCurrent;
  }

  float x = Application::state.current / expectedCurrent;
  x = max(x, -0.5);

  float k = 1.025e10 * sqrt(Feedback::tunnelingBarrierHeight);
  // float F = exp(k * 50e-12);

  float kΔz = x - 1;
  // if (x > F) {
  //   kΔz += (x - F) * (x - F);
  // }
  return kΔz / k;
}

void Feedback::updatePiezoZ() {
  updatePositionErrorDiagnostic();
  float dz = getFeedbackErrorTerm();
  Application::state.feedbackErrorTerm = dz;

  float timeProgress = float(KilohertzLoop::period) / float(integratorTimeLag);
  float correctionInMeters = -dz * timeProgress;

  // v_max = 2 π f_0 A_max
  // v_max = 2 π 1470 Hz * 50e-12 m
  // v_max = 462 nm/s
  // Δx = vΔt = (462 nm/s) * (12 μs)
  // Δx = 5.5e-12 m
  // 80% derated: 4.4e-12 m
  //
  // max dz registered: 
  // -1 / (1.025e10 * sqrt(barrier height)) = -98 pm
  // -(-98 pm) * 12e-6 / 1e-3 = 1.2 pm
  // -(-98 pm) * 12e-6 / 300e-6 = 3.9 pm
  // enforcing the +4.4 pm limit will not change anything
  correctionInMeters = min(correctionInMeters, 4.4e-12);

  // Limit slew rate to 0.52 V/μs.  
  correctionInMeters = max(correctionInMeters, -2e-9);

  float voltage = Application::state.piezoZVoltage;
  voltage += correctionInMeters / 0.320e-9;
  voltage = min(voltage, 270);
  voltage = max(voltage, -80);
  Application::updatePiezoVoltage(3, voltage);
}