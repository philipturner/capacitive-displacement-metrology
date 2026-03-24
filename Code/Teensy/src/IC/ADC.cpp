#include "ADC.h"
#include "../Util/Bitset.h"

uint32_t ADC::transfer(ADCInput input, uint32_t speed) {
  uint8_t bytes[4];
  bytes[0] = input.command << 1;
  bytes[1] = input.registerAddress;
  bytes[2] = uint8_t(input.data >> 8);
  bytes[3] = uint8_t(input.data >> 0);
  
  // Tried different SPI modes with no luck. All of them drop a bit between
  // 15 Mbps and 20 Mbps.
  SPI.beginTransaction(SPISettings(speed, MSBFIRST, SPI_MODE0));
  digitalWrite(CS_ADC, 0);
  SPI.transfer(bytes, 4);
  digitalWrite(CS_ADC, 1);
  SPI.endTransaction();

  uint32_t output = 0;
  output = (output << 8) | bytes[0];
  output = (output << 8) | bytes[1];
  output = (output << 8) | bytes[2];
  output = (output << 8) | bytes[3];

  return output;
}

void ADC::nop() {
  ADCInput input;
  input.command = ADS8699_NOP;
  input.registerAddress = 0;
  input.data = 0;
  transfer(input);
}

ADCOutputConversion ADC::readConversionResult(uint32_t speed) {
  ADCInput input;
  input.command = ADS8699_NOP;
  input.registerAddress = 0;
  input.data = 0;
  uint32_t rawData = transfer(input, speed);

  ADCOutputConversion output(rawData);
  return output;
}

void ADC::writeRegister(uint8_t registerAddress, uint16_t data) {
  ADCInput input;
  input.command = ADS8699_WRITE_FULL;
  input.registerAddress = registerAddress;
  input.data = uint16_t(data);
  transfer(input);
}

// Data transfer process:
//
// frame 0 | input read highest 16 bits | output ignored
// frame 1 | input read lowest 16 bits  | output receive highest 16 bits
// frame 2 | NOP                        | output receive lowest 16 bits
uint32_t ADC::readRegister(uint8_t registerAddress) {
  uint32_t upperBits;
  uint32_t lowerBits;

  // frame 0
  {
    ADCInput input;
    input.command = ADS8699_READ_HWORD;
    input.registerAddress = registerAddress + 2;
    input.data = 0;
    transfer(input);
  }

  // frame 1
  {
    ADCInput input;
    input.command = ADS8699_READ_HWORD;
    input.registerAddress = registerAddress;
    input.data = 0;
    uint32_t rawData = transfer(input);

    ADCOutputHWORD output(rawData);
    upperBits = uint32_t(output.data);
  }

  // frame 2
  {
    ADCInput input;
    input.command = ADS8699_NOP;
    input.registerAddress = 0;
    input.data = 0;
    uint32_t rawData = transfer(input);

    ADCOutputHWORD output(rawData);
    lowerBits = uint32_t(output.data);
  }

  return (upperBits << 16) | lowerBits;
}

void ADC::responsivenessDiagnosticLoop() {
  if (Serial.available() > 0) {
    char incomingByte = Serial.read();

    if (incomingByte == 'c') {
      {
      ADCOutputConversion result = ADC::readConversionResult(18 * 1000000);

      Serial.print("ADC code (fraction of full-scale): ");
      Serial.print(result.floatValue, 6);
      Serial.print(" | ");
      Bitset::print(result.integerValue, 18);
      Serial.print(" | ");
      Bitset::print(result.otherBits, 14);
      Serial.println();

      Serial.println(result.checkParity(0b1101));
      }

      {
      ADCOutputConversion result = ADC::readConversionResult(20 * 1000000);

      Serial.print("ADC code (fraction of full-scale): ");
      Serial.print(result.floatValue, 6);
      Serial.print(" | ");
      Bitset::print(result.integerValue, 18);
      Serial.print(" | ");
      Bitset::print(result.otherBits, 14);
      Serial.println();

      Serial.println(result.checkParity(0b1101));
      }

    } else if (incomingByte == 'd') {
      uint32_t rangeCode = ADC::readRegister(ADS8699_SDI_CTL_REG);
      Serial.print("Contents of SDI_CTL register: ");
      Serial.println(rangeCode);

    } else if (incomingByte == '0') {
      Serial.println("received command '0'");
      ADC::writeRegister(ADS8699_SDI_CTL_REG, 0);

    } else if (incomingByte == '1') {
      Serial.println("received command '1'");
      ADC::writeRegister(ADS8699_SDI_CTL_REG, 1);

    } else if (incomingByte == '2') {
      Serial.println("received command '2'");
      ADC::writeRegister(ADS8699_SDI_CTL_REG, 2);

    } else if (incomingByte == '3') {
      Serial.println("received command '3'");
      ADC::writeRegister(ADS8699_SDI_CTL_REG, 3);

    }
  }
}