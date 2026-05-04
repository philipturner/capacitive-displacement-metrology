#include "KilohertzLoop.h"
#include <Arduino.h>

void KilohertzLoop::_kilohertzLoopBodyInner() {
  previousTimestamp = latestTimestamp;
  latestTimestamp = micros();
  
  if (iterationID == 0) {
    integrationStartTimestamp = latestTimestamp;
  } else {
    int32_t interval = latestTimestamp - previousTimestamp;
    if (interval < 0) {
      Serial.println("Microseconds counter overflowed.");
      exit(0);
    }

    int32_t differentialError = interval - period;
    if (abs(differentialError) > 1) {
      Serial.println("Differential error was too large.");
      exit(0);
    }
    
    uint32_t actualIntegrated = latestTimestamp - integrationStartTimestamp;
    uint32_t expectedIntegrated = (iterationID - 1) * period;
    expectedIntegrated += period;

    int32_t integralError = actualIntegrated - expectedIntegrated;
    if (abs(integralError) > 1) {
      Serial.println("Integral error was too large.");
      exit(0);
    }
  }

  loopBody();

  iterationID += 1;
}

void _kilohertzLoopBodyOuter() {
  KilohertzLoop::_kilohertzLoopBodyInner();
}

void KilohertzLoop::initialize(
  teensy::inplace_function<void(void), 16> loopBody,
  uint32_t period
) {
  KilohertzLoop::loopBody = loopBody;
  KilohertzLoop::period = period;

  uint32_t timestamp = micros();
  KilohertzLoop::startTimestamp = timestamp;
  KilohertzLoop::previousTimestamp = timestamp;
  KilohertzLoop::latestTimestamp = timestamp;

  KilohertzLoop::timer.begin(_kilohertzLoopBodyOuter, period);
}