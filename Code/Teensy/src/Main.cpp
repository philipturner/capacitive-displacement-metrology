#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Time/KilohertzLoop.h"
#include "Time/Oscilloscope.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

// MARK: - Utilities

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

#define CDC_HISTORY_SIZE 27
float capacitanceHistory[CDC_HISTORY_SIZE] = {};
uint32_t capacitanceSampleID = 0;

// CDC must be in continuous conversion mode (0b001).
void basicCapacitanceMeasurementLoop() {
  delay(10);

  uint8_t status = CDC::readRegister(AD7745_STATUS);
  if (status & 0b00000100) {
    return;
  }

  float time = float(millis()) / 1000;
  float capacitance = CDC::readCapacitance();
  capacitanceHistory[capacitanceSampleID % CDC_HISTORY_SIZE] = capacitance;
  capacitanceSampleID += 1;

  // Calculate the trailing average.
  float capacitanceAverage = 0;
  for (uint32_t i = 0; i < CDC_HISTORY_SIZE; ++i) {
    float sample = capacitanceHistory[i];
    capacitanceAverage += sample;
  }
  capacitanceAverage /= float(CDC_HISTORY_SIZE);

  // Display the capacitance.
  Serial.println();

  Serial.print("time: ");
  Serial.println(time, 3);

  Serial.print("capacitance:                ");
  Serial.print(capacitance, 6);
  Serial.println(" pF");

  Serial.print(CDC_HISTORY_SIZE);
  Serial.print("-sample trailing average: ");
  Serial.print(capacitanceAverage, 6);
  Serial.println(" pF");
}

// MARK: - Setup and Loop

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();

  
}

void loop() {
  // Check the voltage waveform on the oscilloscope.
}
