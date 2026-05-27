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
float getFeedbackErrorTerm() {
  float expectedCurrent = abs(Feedback::setpointCurrent);
  if (Feedback::setpointVoltage < 0) {
    expectedCurrent = -expectedCurrent;
  }

  float x = Application::state.current / expectedCurrent;
  x = max(x, -0.5);

  float k = 1.025e10 * sqrt(Feedback::tunnelingBarrierHeight);
  float F = exp(k * 50e-12);
  if (x > F) {
    // Check that F is correct.
    Application::state.positionError = 300e-12;
  }

  float kΔz = x - 1;
  if (x > F) {
    kΔz += (x - F) * (x - F);
  }
  return kΔz / k;
}

void Feedback::updatePiezoZ() {
  updatePositionErrorDiagnostic();
  float dz = getFeedbackErrorTerm();
  Application::state.feedbackErrorTerm = dz;

  float timeProgress = float(KilohertzLoop::period) / float(integratorTimeLag);
  float correctionInMeters = -dz * timeProgress;

  // Limit slew rate to 0.52 V/μs.
  correctionInMeters = min(correctionInMeters, 2e-9);
  correctionInMeters = max(correctionInMeters, -2e-9);
  float correctionInVolts = correctionInMeters / 0.320e-9;

  float voltage = Application::state.piezoZVoltage;
  voltage += correctionInVolts;
  voltage = min(voltage, 270);
  voltage = max(voltage, -130);
  Application::updatePiezoVoltage(3, voltage);
}