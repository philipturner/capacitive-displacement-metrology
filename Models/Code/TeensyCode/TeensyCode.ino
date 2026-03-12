#include "src/ADC.h"
#include "KeyboardInput.h"
#include "RingBuffer.h"
#include "TimeStatistics.h"

IntervalTimer timer;

void setup() {
  Serial.begin(0);
  Serial.println(); // allow easy distinction of different program runs
  Serial.println("Serial Monitor has initialized.");

  pinMode(CS_ADC, OUTPUT);
  digitalWrite(CS_ADC, 1);
  SPI.begin(); 
 
  ADC::writeRangeSelect(0b0000);
  ADC::nop(); // prepare for the first sample

  startTimestamp = micros();
  latestTimestamp = startTimestamp;
  oscilloscopeTimestamp = startTimestamp;

  // Omit for ADC responsiveness loop.
  // 20 kHz (50 μs) when SPI rate reduced to 5 MHz
  // 50 kHz (20 μs) otherwise
  timer.begin(kilohertzLoop, 20);
}

void loop() {
  //timeFidelityDiagnosticLoop();
  //adcResponsivenessDiagnosticLoop();
  //oscilloscopeDiagnosticLoop();
}

// Function to execute reliably with a consistent time
// base in the multiple kHz band.
void kilohertzLoop() {
  if (oscilloscopeLock) {
    // Never encountered this after about a minute of testing,
    // although the code guarded by the lock was very small.
    //
    // You must include the 20 ms delay at the start of the
    // oscilloscope loop. Otherwise, this early return will
    // get hit roughly 10% of the time.
    return;
  }

  uint32_t currentTimestamp = micros();
  uint32_t previousTimestamp = latestTimestamp;
  latestTimestamp = currentTimestamp;
  float timeSeconds = float(currentTimestamp - startTimestamp);
  timeSeconds /= float(1000000);

  // Get the ADC data as soon as possible.
  float voltage = ADC::readConversionCode();
  voltage = 2 * voltage - 1;
  voltage *= 12.288;
  
  // 1 kHz artificial sine wave for testing.
  //float voltage = sin(2 * M_PI * 1000 * timeSeconds);
  //voltage *= 10;

  uint32_t jumpDuration = currentTimestamp - previousTimestamp;
  timeStatistics.integrate(jumpDuration);

  uint32_t startSlotID = (previousTimestamp - startTimestamp) / 20;
  startSlotID += 1;
  uint32_t endSlotID = (currentTimestamp - startTimestamp) / 20;
  endSlotID += 1;
  if (endSlotID - startSlotID > 100) {
    Serial.println("Function was overloaded with work.");
    exit(0);
  }

  for (uint32_t slotID = startSlotID; slotID < endSlotID; ++slotID) {
    ringBuffer.samples[slotID % 50000] = voltage;
  }
}