#include "KilohertzLoop.h"

#include "../Diagnostics/ErrorMessage.h"
#include <Arduino.h>

// Timing limits:
//
// 4 us - DAC
//
// 5 us - DAC (2x)
// 6 us - DAC, ADC
//
// 7 us - DAC (3x)
// 8 us - DAC (2x), ADC
//
// 9 us - DAC (4x)
// 11 us - DAC (5x)

void KilohertzLoop::_kilohertzLoopBodyInner() {
  // During a fatal error condition, code in the fast loop should be prevented
  // from being called. We achieve this by ending the kilohertz loop. However,
  // we cannot guarantee that calling 'end()' prevents the subsequent loop
  // iteration from being invoked.
  if (ErrorMessage::errorType == ErrorMessage::Type::fatal) {
    return;
  }

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
  //
  // with recent changes to code:
  // 12 us: fail with -7 error
  // 7 us: fail with -7 error
  // 6 us: fail with -11 error

  // no priority
  // 20 us: fail with +23 error
  // 6 us: fail with +14 error
  
  if (iterationID == 0) {
    integrationStartTimestamp = latestTimestamp;
  } else {
    int32_t interval = latestTimestamp - previousTimestamp;
    if (interval < 0) {
      throwError(
        "Microseconds counter overflowed.",
        startTimestamp,
        previousTimestamp,
        latestTimestamp);
      return;
    }

    int32_t maxError = 10;

    int32_t differentialError = interval - period;
    if (abs(differentialError) > maxError) {
      throwError(
        "Differential error was too large.",
        period,
        interval,
        differentialError);
      return;
    }
    
    uint32_t actualIntegrated = latestTimestamp - integrationStartTimestamp;
    uint32_t expectedIntegrated = (iterationID - 1) * period;
    expectedIntegrated += period;
    
    int32_t integralError = actualIntegrated - expectedIntegrated;
    if (abs(integralError) > maxError) {
      throwError(
        "Integral error was too large.",
        expectedIntegrated,
        actualIntegrated,
        integralError);
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

void KilohertzLoop::throwError(
  const char *cString, 
  int32_t number1,
  int32_t number2,
  int32_t number3
) {
  timer.end();

  if (ErrorMessage::errorType == ErrorMessage::Type::fatal) {
    return;
  }

  ErrorMessage::reset();
  ErrorMessage::errorType = ErrorMessage::Type::fatal;

  ErrorMessage::addString("KilohertzLoop failed.");
  ErrorMessage::addNewline();
  ErrorMessage::addString(cString);
  ErrorMessage::addNewline();

  ErrorMessage::addInteger(number1);
  ErrorMessage::addNewline();
  ErrorMessage::addInteger(number2);
  ErrorMessage::addNewline();
  ErrorMessage::addInteger(number3);
  ErrorMessage::addNewline();
}