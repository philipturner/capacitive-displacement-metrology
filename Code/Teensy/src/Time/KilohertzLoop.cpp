#include "KilohertzLoop.h"
#include <Arduino.h>

void KilohertzLoop::_kilohertzLoopBodyInner() {
  previousTimestamp = latestTimestamp;
  latestTimestamp = micros();

  // Failures from constantly stopping and restarting the serial connection,
  // while logging about 45 bytes every 100 us.

  // timer.priority(0)
  // 20 us: fail with -4 error
  // 10 us: fail with -2 error
  // 9 us: fail with -5 error
  // 8 us: fail with +1 error
  // 7 us: fail with -5 error
  // 6 us: fail with -5 error

  // no priority
  // 20 us: fail with +23 error
  // 6 us: fail with +14 error
  
  if (iterationID == 0) {
    integrationStartTimestamp = latestTimestamp;
  } else {
    int32_t interval = latestTimestamp - previousTimestamp;
    if (interval < 0) {
      Serial.print(startTimestamp);
      Serial.print(previousTimestamp);
      Serial.print(latestTimestamp);
      Serial.println("Microseconds counter overflowed.");

      uint32_t errorCode = 1000;
      if (latestTimestamp > previousTimestamp) {
        errorCode += 10;
      }
      if (latestTimestamp > startTimestamp) {
        errorCode += 1;
      }
      throwError(1000 + errorCode);
      return;
    }

    int32_t differentialError = interval - period;
    if (abs(differentialError) > 6) {
      Serial.println("Differential error was too large.");
      throwError(2000 + interval);
      return;
    }
    
    uint32_t actualIntegrated = latestTimestamp - integrationStartTimestamp;
    uint32_t expectedIntegrated = (iterationID - 1) * period;
    expectedIntegrated += period;
    
    int32_t integralError = actualIntegrated - expectedIntegrated;
    if (abs(integralError) > 6) {
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