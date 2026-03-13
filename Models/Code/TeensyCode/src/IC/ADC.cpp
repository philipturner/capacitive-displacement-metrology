#include "ADC.h"

// 50 Ksps voltage measurement from 18-bit ADC
//
// 6000 ns breathing room for CONV
//         write CS low
//  100 ns breathing room to start SPI transfer
// 1600 ns transfer 32 bits @ 20 Mbps
// 6000 ns breathing room for ACQ
//         write CS high
// 6300 ns theoretical time left for other code
//
// TODO: Find ways to do other work during these 6000 ns
// waits. Also, one of the two waits might not be needed.
uint32_t ADC::transfer(ADCInput input, uint32_t speed) {
  uint8_t bytes[4];
  bytes[0] = input.command << 1;
  bytes[1] = input.registerAddress;
  bytes[2] = uint8_t(input.data >> 8);
  bytes[3] = uint8_t(input.data >> 0);
  
  // Guarantee that enough conversion time has passed.
  delayNanoseconds(6000);

  SPI.beginTransaction(SPISettings(speed, MSBFIRST, SPI_MODE0));
  digitalWrite(CS_ADC, 0);
  delayNanoseconds(100);

  // 32 bits at 20 MHz, 1600 ns delay
  SPI.transfer(bytes, 4);

  // Minimize EMI from digital signals while analog is acquiring.
  delayNanoseconds(6000);
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
  input.command = ADS8689_NOP;
  input.registerAddress = 0;
  input.data = 0;
  transfer(input);
}

float ADC::readConversionCode() {
  ADCInput input;
  input.command = ADS8689_NOP;
  input.registerAddress = 0;
  input.data = 0;
  uint32_t rawData = transfer(input);

  ADCOutputConversion output(rawData);
  return output.data;
}

void ADC::writeRangeSelect(uint8_t rangeCode) {
  ADCInput input;
  input.command = ADS8689_WRITE_FULL;
  input.registerAddress = ADS8689_RANGE_SEL_REG;
  input.data = uint16_t(rangeCode);
  transfer(input);
}

// Data transfer process:
//
// frame 0 | input read highest 16 bits | output ignored
// frame 1 | input read lowest 16 bits  | output receive highest 16 bits
// frame 2 | NOP                        | output receive lowest 16 bits
uint32_t ADC::readRangeSelect() {
  uint32_t upperBits;
  uint32_t lowerBits;

  // frame 0
  {
    ADCInput input;
    input.command = ADS8689_READ_HWORD;
    input.registerAddress = ADS8689_RANGE_SEL_REG + 2;
    input.data = 0;
    transfer(input);
  }

  // frame 1
  {
    ADCInput input;
    input.command = ADS8689_READ_HWORD;
    input.registerAddress = ADS8689_RANGE_SEL_REG;
    input.data = 0;
    uint32_t rawData = transfer(input);

    ADCOutputHWORD output(rawData);
    upperBits = uint32_t(output.data);
  }

  // frame 2
  {
    ADCInput input;
    input.command = ADS8689_NOP;
    input.registerAddress = 0;
    input.data = 0;
    uint32_t rawData = transfer(input);

    ADCOutputHWORD output(rawData);
    lowerBits = uint32_t(output.data);
  }

  return (upperBits << 16) | lowerBits;
}

void adcResponsivenessDiagnosticLoop() {
  if (Serial.available() > 0) {
    char incomingByte = Serial.read();

    if (incomingByte == 'c') {
      Serial.println("received command 'c'");

      float voltage = ADC::readConversionCode();
      Serial.print("ADC code (fraction of full-scale): ");
      Serial.println(voltage, 6); // force it to 6 decimal places
    } else if (incomingByte == 'd') {
      Serial.println("received command 'd'");
      
      uint32_t rangeCode = ADC::readRangeSelect();
      Serial.print("Contents of range select register: ");
      Serial.println(rangeCode);
    } else if (incomingByte == '0') {
      Serial.println("received command '0'");
      
      ADC::writeRangeSelect(0b0000);
    } else if (incomingByte == '1') {
      Serial.println("received command '1'");
      
      ADC::writeRangeSelect(0b0001);
    }
  }
}