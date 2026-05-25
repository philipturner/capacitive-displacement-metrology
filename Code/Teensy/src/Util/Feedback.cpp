#include "Feedback.h"

#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include <Arduino.h>

void Feedback::update() {
  float currentMagnitude = abs(Application::state.filteredCurrent);
  currentMagnitude = max(currentMagnitude, 2e-12);
  float dlnI = log(currentMagnitude / setpointCurrent);

  // Position error in meters. Positive means you're too close, correct it
  // by moving backward (more negative voltage).
  float dlnI_dz = 1.025e10 * sqrt(tunnelingBarrierHeight);
  float dz = dlnI / dlnI_dz;
  Application::state.positionError = dz;

  // The key to preventing tip crashes!
  if (dlnI > 0) {
    dz *= currentMagnitude / setpointCurrent;
  }

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