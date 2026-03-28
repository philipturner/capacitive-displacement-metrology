#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Time/Oscilloscope.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();

  CDC::writeCAPDAC(true, 20);
  CDC::writeConfiguration(0b001);
}

#define TRAILING_AVERAGE_HISTORY_SIZE 27
float history[TRAILING_AVERAGE_HISTORY_SIZE] = {};
uint32_t sampleID = 0;

#define VELOCITY_HISTORY_SIZE 27
float lastAverages[VELOCITY_HISTORY_SIZE];
float lastTimes[VELOCITY_HISTORY_SIZE];

float dCdt(uint32_t startPos) {
  float dC = lastAverages[VELOCITY_HISTORY_SIZE - 1];
  dC -= lastAverages[startPos];
  float dt = lastTimes[VELOCITY_HISTORY_SIZE - 1];
  dt -= lastTimes[startPos];

  return dC / dt;
}

void loop() {
  #if 1
  delay(10);

  uint8_t status = CDC::readRegister(AD7745_STATUS);
  if (status & 0b00000100) {
    return;
  }

  float time = float(millis()) / 1000;
  float capacitance = CDC::readCapacitance();
  history[sampleID % TRAILING_AVERAGE_HISTORY_SIZE] = capacitance;
  sampleID += 1;

  // Calculate the trailing average.
  float capacitanceAverage = 0;
  for (uint32_t i = 0; i < TRAILING_AVERAGE_HISTORY_SIZE; ++i) {
    float sample = history[i];
    capacitanceAverage += sample;
  }
  capacitanceAverage /= float(TRAILING_AVERAGE_HISTORY_SIZE);

  // Store in the history for velocity.
  for (uint32_t i = 0; i < VELOCITY_HISTORY_SIZE - 1; ++i) {
    lastAverages[i] = lastAverages[i + 1];
    lastTimes[i] = lastTimes[i + 1];
  }
  lastAverages[VELOCITY_HISTORY_SIZE - 1] = capacitanceAverage;
  lastTimes[VELOCITY_HISTORY_SIZE - 1] = time;

  // Calculate the velocity.
  float dCdt_fast = dCdt(VELOCITY_HISTORY_SIZE - 4);
  float dCdt_slow = dCdt(0);

  Serial.println();

  Serial.print("time: ");
  Serial.println(time, 3);

  Serial.print("capacitance:                ");
  Serial.print(capacitance, 6);
  Serial.println(" pF");

  Serial.print(TRAILING_AVERAGE_HISTORY_SIZE);
  Serial.print("-sample trailing average: ");
  Serial.print(capacitanceAverage, 6);
  Serial.println(" pF");

  Serial.print("[ 4-point average] dC/dt: ");
  if (dCdt_fast >= 0) {
    Serial.print(" ");
  }
  Serial.print(dCdt_fast, 6);
  Serial.println(" pF/sec");

  Serial.print("[");
  Serial.print(TRAILING_AVERAGE_HISTORY_SIZE);
  Serial.print("-point average] dC/dt: ");
  if (dCdt_slow >= 0) {
    Serial.print(" ");
  }
  Serial.print(dCdt_slow, 6);
  Serial.println(" pF/sec");
  #endif
}