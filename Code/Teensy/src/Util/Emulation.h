#pragma once

struct Emulation {
  static constexpr float atomSpacing = 0.246; // units: nm
  static constexpr float slopeX = 0.05;
  static constexpr float slopeY = -0.02;
  static constexpr float zeroPositionZ = 10; // units: nm, sign convention of voltage
  
  static float getCurrent(float voltageX, float voltageY, float voltageZ);
};