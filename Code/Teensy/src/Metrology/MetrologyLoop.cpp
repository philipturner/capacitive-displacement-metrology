#include "IC/CDC.h"
#include <Arduino.h>
#include "Metrology.h"

void Metrology::waveformTestingLoop() {
  float bipolarVoltage = metrologyDesc.waveformBipolarVoltage;

  delay(10);
  changeVoltage(-bipolarVoltage, bipolarVoltage);
  delay(10);
  changeVoltage(bipolarVoltage, -bipolarVoltage);
}

void Metrology::basicCapacitanceMeasurementLoop() {
  delay(10);

  uint8_t status = CDC::readRegister(AD7745_STATUS);
  if (status & 0b00000100) {
    return;
  }

  float time = float(millis()) / 1000;
  float capacitance = CDC::readCapacitance();
  capacitance -= CDC::capdacOffset(metrologyDesc.cdcCapdacCode);
  capacitanceHistory[
    infiniteLoopIndex % metrologyDesc.basicMeasurementHistorySize] = capacitance;
  infiniteLoopIndex += 1;

  // Calculate the trailing average.
  float capacitanceAverage = 0;
  for (uint32_t i = 0; i < metrologyDesc.basicMeasurementHistorySize; ++i) {
    float sample = capacitanceHistory[i];
    capacitanceAverage += sample;
  }
  capacitanceAverage /= float(metrologyDesc.basicMeasurementHistorySize);

  // Display the capacitance.
  Serial.println();

  Serial.print("time: ");
  Serial.print(time, 3);
  Serial.println(" s");

  Serial.print("capacitance:                 ");
  Serial.print(capacitance, 6);
  Serial.println(" pF");

  if (metrologyDesc.basicMeasurementHistorySize < 100) {
    Serial.print(" ");
  }
  if (metrologyDesc.basicMeasurementHistorySize < 10) {
    Serial.print(" ");
  }
  Serial.print(metrologyDesc.basicMeasurementHistorySize);
  Serial.print("-sample trailing average: ");
  Serial.print(capacitanceAverage, 6);
  Serial.println(" pF");
}