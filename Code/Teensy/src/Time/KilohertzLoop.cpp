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
      throwError(1000);
      return;
    }

    int32_t differentialError = interval - period;
    if (abs(differentialError) >= period) {
      Serial.println("Differential error was too large.");
      throwError(2000 + interval);
      return;
    }
    
    uint32_t actualIntegrated = latestTimestamp - integrationStartTimestamp;
    uint32_t expectedIntegrated = (iterationID - 1) * period;
    expectedIntegrated += period;

    int32_t integralError = actualIntegrated - expectedIntegrated;
    if (abs(integralError) >= period) {
      Serial.println("Integral error was too large.");
      throwError(3000 + integralError);
      return;
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
  startTimestamp = timestamp;
  previousTimestamp = timestamp;
  latestTimestamp = timestamp;

  integrationStartTimestamp = 0;
  iterationID = 0;

  timer.priority(0);
  timer.begin(_kilohertzLoopBodyOuter, period);
}

void KilohertzLoop::throwError(uint32_t inputCode) {
  errorCode = inputCode;
  timer.end();
}