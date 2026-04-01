#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Time/KilohertzLoop.h"
#include "Time/Oscilloscope.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

// Input: progress, 0 to 1
// Output: interpolation, 0 to 1
float smoothstep(float progress) {
  if (progress < 0) {
    return 0;
  } else if (progress > 1) {
    return 1;
  } else {
    return 3 * progress * progress - 2 * progress * progress * progress;
  }
}

void changeVoltage(float startVoltage, float endVoltage) {
  constexpr uint32_t stallTimeMicroseconds = 4;
  constexpr float duration = 10e-3;

  uint32_t startTime = micros();
  while (true) {
    delayMicroseconds(stallTimeMicroseconds);
    uint32_t latestTime = micros();
    float elapsedTime = float(latestTime - startTime) / float(1e6);

    float timeProgress = elapsedTime / duration;
    float voltageProgress = smoothstep(timeProgress);

    float voltage = 0;
    voltage += voltageProgress * endVoltage;
    voltage += (1 - voltageProgress) * startVoltage;
    DAC2::writeVoltage(0, voltage);

    if (elapsedTime > duration) {
      break;
    }
  }

}

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();

  
}

void loop() {
  // Check the voltage waveform on the oscilloscope.
}
