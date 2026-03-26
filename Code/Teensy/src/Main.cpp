#include "IC/CDC.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

void setup() {
  Application::setupSerial();
  Application::setupSPI();

  // I2C test routine.
  #if 1
  master.begin(400000);

  uint8_t status = 0;
  CDC::check(sensor.read(AD7745_STATUS, &status, true));

  uint8_t vtData[3] = { 0, 0, 0 };
  CDC::check(sensor.read(AD7745_VT_DATA, vtData, 3, true));

  uint8_t capSetup1 = 0;
  uint8_t capSetupValue = 0b10000001;
  uint8_t capSetup2 = 0;
  CDC::check(sensor.read(AD7745_CAP_SETUP, &capSetup1, true));
  CDC::check(sensor.write(AD7745_CAP_SETUP, capSetupValue, true));
  CDC::check(sensor.read(AD7745_CAP_SETUP, &capSetup2, true));

  uint8_t vtSetup1 = 0;
  uint8_t vtSetupValue = 0b00000001;
  uint8_t vtSetup2 = 0;
  CDC::check(sensor.read(AD7745_VT_SETUP, &vtSetup1, true));
  CDC::check(sensor.write(AD7745_VT_SETUP, vtSetupValue, true));
  CDC::check(sensor.read(AD7745_VT_SETUP, &vtSetup2, true));

  uint8_t excSetup1 = 0;
  uint8_t excSetupValue = 0b00001011;
  uint8_t excSetup2 = 0;
  CDC::check(sensor.read(AD7745_EXC_SETUP, &excSetup1, true));
  CDC::check(sensor.write(AD7745_EXC_SETUP, excSetupValue, true));
  CDC::check(sensor.read(AD7745_EXC_SETUP, &excSetup2, true));

  uint8_t configuration1 = 0;
  uint8_t configurationValue = 0b11111001;
  uint8_t configuration2 = 0;
  CDC::check(sensor.read(AD7745_CONFIGURATION, &configuration1, true));
  CDC::check(sensor.write(AD7745_CONFIGURATION, configurationValue, true));
  CDC::check(sensor.read(AD7745_CONFIGURATION, &configuration2, true));

  uint8_t capdac1 = 0;
  uint8_t capdacValue = 0b10001010;
  uint8_t capdac2 = 0;
  CDC::check(sensor.read(AD7745_CAP_DAC_A, &capdac1, true));
  CDC::check(sensor.write(AD7745_CAP_DAC_A, capdacValue, true));
  CDC::check(sensor.read(AD7745_CAP_DAC_A, &capdac2, true));

  /*
  Serial.print("contents of STATUS register: ");
  Bitset::printBinary(status, 8);
  Serial.println();

  Serial.print("contents of VT_DATA register: ");
  for (uint32_t byteID = 0; byteID < 3; ++byteID) {
    Bitset::printBinary(vtData[byteID], 8);
    Serial.print(" ");
  }
  Serial.println();

  Serial.print("temperature: ");
  Serial.print(CDC::decodeTemperature(vtData), 1);
  Serial.println("°C");
  
  Serial.print("supply voltage: ");
  Serial.print(CDC::decodeVoltage(vtData) * 5.97, 6);
  Serial.println(" V");

  uint32_t voltageCode = 0;
  voltageCode |= uint32_t(vtData[0]) << 16;
  voltageCode |= uint32_t(vtData[1]) << 8;
  voltageCode |= uint32_t(vtData[2]);
  Serial.println(voltageCode);
  */

  Serial.print("contents of VT_SETUP register: ");
  Bitset::printBinary(vtSetup1, 8);
  Serial.println();

  Serial.print("contents of VT_SETUP register: ");
  Bitset::printBinary(vtSetup2, 8);
  Serial.println();

  Serial.print("contents of EXC_SETUP register: ");
  Bitset::printBinary(excSetup1, 8);
  Serial.println();

  Serial.print("contents of EXC_SETUP register: ");
  Bitset::printBinary(excSetup2, 8);
  Serial.println();

  Serial.print("contents of CONFIGURATION register: ");
  Bitset::printBinary(configuration1, 8);
  Serial.println();
  
  Serial.print("contents of CONFIGURATION register: ");
  Bitset::printBinary(configuration2, 8);
  Serial.println();

  Serial.print("contents of CAP_DAC_A register: ");
  Bitset::printBinary(capdac1, 8);
  Serial.println();
  
  Serial.print("contents of CAP_DAC_A register: ");
  Bitset::printBinary(capdac2, 8);
  Serial.println();

  #endif
}

void loop() {
  #if 1
  delay(10);

  uint8_t status = 0;
  CDC::check(sensor.read(AD7745_STATUS, &status, true));
  if (status & 0b00000100) {
    return;
  }

  uint8_t capData[3] = { 0, 0, 0 };
  CDC::check(sensor.read(AD7745_CAP_DATA, capData, 3, true));

  uint32_t timeMillis = millis();
  float timeSeconds = float(timeMillis) / 1000;
  Serial.println();
  Serial.print("time: ");
  Serial.println(timeSeconds, 3);

  Serial.print("contents of CAP_DATA register: ");
  for (uint32_t byteID = 0; byteID < 3; ++byteID) {
    Bitset::printBinary(capData[byteID], 8);
    Serial.print(" ");
  }
  Serial.println();

  Serial.print("capacitance: ");
  Serial.print(CDC::decodeCapacitance(capData), 6);
  Serial.println(" pF");
  #endif
}
