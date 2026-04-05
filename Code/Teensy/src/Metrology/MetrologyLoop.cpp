void waveformTestingLoop() {
  delay(10);
  changeVoltage(-BIPOLAR_DRIVE_VOLTAGE, BIPOLAR_DRIVE_VOLTAGE);
  delay(10);
  changeVoltage(BIPOLAR_DRIVE_VOLTAGE, -BIPOLAR_DRIVE_VOLTAGE);
}

void basicCapacitanceMeasurementLoop() {
  delay(10);

  uint8_t status = CDC::readRegister(AD7745_STATUS);
  if (status & 0b00000100) {
    return;
  }

  float time = float(millis()) / 1000;
  float capacitance = CDC::readCapacitance();
  capacitance -= CDC::capdacOffset(CDC_CAPDAC_CODE);
  capacitanceHistory[infiniteLoopIndex % CDC_HISTORY_SIZE] = capacitance;
  infiniteLoopIndex += 1;

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
  Serial.print(time, 3);
  Serial.println(" s");

  Serial.print("capacitance:                 ");
  Serial.print(capacitance, 6);
  Serial.println(" pF");

  if (CDC_HISTORY_SIZE < 100) {
    Serial.print(" ");
  }
  Serial.print(CDC_HISTORY_SIZE);
  Serial.print("-sample trailing average: ");
  Serial.print(capacitanceAverage, 6);
  Serial.println(" pF");
}