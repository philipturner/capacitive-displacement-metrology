#include "IC/CDC.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();

  CDC::writeConfiguration(0b001);
}

#define TRAILING_AVERAGE_HISTORY_SIZE 27
float history[TRAILING_AVERAGE_HISTORY_SIZE] = {};
uint32_t sampleID = 0;

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

  Serial.println();

  Serial.print("time: ");
  Serial.println(time, 3);

  Serial.print("capacitance: ");
  Serial.print(capacitance, 6);
  Serial.println(" pF");

  Serial.print(TRAILING_AVERAGE_HISTORY_SIZE);
  Serial.print("-sample trailing average: ");
  Serial.print(capacitanceAverage, 6);
  Serial.println();
  #endif
}
