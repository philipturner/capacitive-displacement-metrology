#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "Time/KilohertzLoop.h"
#include "Time/Oscilloscope.h"
#include "Util/Bitset.h"

I2CMaster& master = Master;
I2CDevice sensor = I2CDevice(master, 0x48, _BIG_ENDIAN);

void setup() {
  // Set up USB serial.
  Serial.begin(0);
  Serial.println(); // allow easy distinction of different program runs
  Serial.println("Serial Monitor has initialized.");

  // SPI test routine.
  #if 0

  // Set up SPI.
  pinMode(CS_DAC1, OUTPUT);
  pinMode(CS_DAC2, OUTPUT);
  pinMode(CS_ADC, OUTPUT);
  digitalWrite(CS_DAC1, 1);
  digitalWrite(CS_DAC2, 1);
  digitalWrite(CS_ADC, 1);
  SPI.begin();

  // Set up ADC.
  ADC::writeRegister(ADS8699_DATAOUT_CTL_REG, 0x4000 | 0b1000);
  ADC::writeRegister(ADS8699_DEVICE_ID_REG + 2, 0b1101);

  DAC1::writeRegister(DAC81404_SPICONFIG, 0b10010110, CRC::Flags::NONE);
  DAC1::writeRegister(DAC81404_GENCONFIG, 0x0000, CRC::Flags::MOSI);
  DAC1::writeRegister(DAC81404_DACPWDWN, 0xFFF0);
  DAC1::writeRegister(DAC81404_DACRANGE, 0x5555);
  DAC1::writeVoltage(2, 0.35 * 10 - 5);

  uint16_t deviceID = DAC1::readRegister(DAC81404_DEVICEID);
  uint16_t deviceIDAgain = DAC1::readRegister(DAC81404_DEVICEID);

  Serial.print("deviceID: ");
  Serial.print(deviceID);
  Serial.print(" ");
  Serial.println(deviceIDAgain);

  Serial.print("expected: ");
  Serial.print(0x029C);
  Serial.print(" ");
  Serial.println(0x029C);

  #endif

  // I2C test routine.
  #if 1
  master.begin(400000);

  uint8_t status = 0;
  CDC::check(sensor.read(AD7745_STATUS, &status, true));
  Serial.print("contents of STATUS register: ");
  Bitset::printBinary(status, 8);
  Serial.println();

  uint16_t capOffset = 0;
  uint16_t capGain = 0;
  uint16_t voltGain = 0;
  CDC::check(sensor.read(AD7745_CAP_OFFSET, &capOffset, true));
  CDC::check(sensor.read(AD7745_CAP_GAIN, &capGain, true));
  CDC::check(sensor.read(AD7745_VOLT_GAIN, &voltGain, true));

  Serial.print("contents of CAP_OFFSET register: ");
  Bitset::printBinary(capOffset, 16);
  Serial.println();

  Serial.print("contents of CAP_GAIN register: ");
  Bitset::printBinary(capGain, 16);
  Serial.println();

  Serial.print("contents of VOLT_GAIN register: ");
  Bitset::printBinary(voltGain, 16);
  Serial.println();

  #endif
}

void loop() {
  
}
