#include "Emulation.h"

#include "Filter/Feedback.h"
#include "Time/KilohertzLoop.h"
#include <Arduino.h>

void Emulation::updateSecondOrderFilter(float voltageZ) {
  secondOrderFilter.update(voltageZ);
}

float getDriftOffset() {
  uint32_t periodMicros = float(1e6 / Emulation::driftFrequency);
  uint32_t periodIters = periodMicros / KilohertzLoop::period;

  uint32_t phase = KilohertzLoop::iterationID % periodIters;
  float phaseNormalized = float(phase) / float(periodIters);

  float amplitude = Emulation::driftRate / (float(2 * M_PI) * Emulation::driftFrequency);
  float amplitudeNormalized = sinf(phaseNormalized * float(2 * M_PI));
  return amplitude * amplitudeNormalized;
}

float getRelativeZ(float positionX, float positionY, float positionZ) {
  float predictedZ = Emulation::zeroPositionZ;
  predictedZ += getDriftOffset();
  predictedZ += Emulation::slopeX * positionX;
  predictedZ += Emulation::slopeY * positionY;
  return positionZ - predictedZ;
}

float getBaseCurrent(float relativePositionZ) {
  float distanceFromAtom = -relativePositionZ * 1e-9f; // units: m
  float k = 1.025e10f * sqrt(Feedback::tunnelingBarrierHeight);
  float kΔz = k * distanceFromAtom;
  if (kΔz < 0) {
    // HOPG elastic deformation causing apparent 0.01 V barrier height
    // (2250 pm/decade) instead of expected 1.0 V (225 pm/decade).
    kΔz /= 10;
  }
  kΔz = min(kΔz, 13.0f);
  kΔz = max(kΔz, -13.0f);

  float output = exp(-kΔz);
  output *= Feedback::setpointCurrent;
  return output;
}

float getRandomGaussian() {
  uint32_t randomNumber = random() << 1;
  uint16_t lowerBits = randomNumber & 0xFFFF;
  uint16_t upperBits = randomNumber >> 16;

  float u1 = float(lowerBits) / float(65535);
  float u2 = float(upperBits) / float(65535);
  u1 = max(u1, 0.001f);

  return sqrtf(-2.0f * logf(u1)) * cosf(float(2 * M_PI) * u2);
}

float getCorrugationAmplitude(float positionX, float positionY) {
  float x = positionX / Emulation::atomSpacing;
  float y = positionY / Emulation::atomSpacing;

  float phases[3];
  phases[0] = x;
  phases[1] = -0.5f * x + float(M_SQRT3 / 2) * y;
  phases[2] = -0.5f * x - float(M_SQRT3 / 2) * y;

  float accumulator = 0;
  for (uint32_t laneID = 0; laneID < 3; ++laneID) {
    float phaseNormalized = phases[laneID];
    phaseNormalized -= floor(phaseNormalized);
    accumulator += cosf(float(2 * M_PI) * phaseNormalized);
  }
  return accumulator / 3.0f;
}

float Emulation::getCurrent(float voltageX, float voltageY) {
  float voltageZ = secondOrderFilter.getOutput();
  float positionX = voltageX * 0.320f;
  float positionY = voltageY * 0.320f;
  float positionZ = voltageZ * 0.320f;

  float relativeZ = getRelativeZ(positionX, positionY, positionZ);
  float baseCurrent = getBaseCurrent(relativeZ);

  float normalizedCurrent = 1;
  normalizedCurrent += 0.2f * getCorrugationAmplitude(positionX, positionY);
  normalizedCurrent += 0.03f * getRandomGaussian();
  
  float output = baseCurrent * normalizedCurrent;
  output = min(output, 12000e-12f);
  output = max(output, 0.1e-12f);
  return output;
}