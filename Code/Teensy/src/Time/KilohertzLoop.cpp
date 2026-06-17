#include "KilohertzLoop.h"

#include "Application/Application.h"
#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
#include <Arduino.h>

bool shouldWarn(int64_t differentialError, int64_t integralError) {
  if (KilohertzLoop::iterationID % 1997 == 0) {
    return true;
  } else {
    return false;
  }

  if (abs(differentialError) > KilohertzLoop::differentialErrorWarning) {
    return true;
  }
  if (abs(integralError) > KilohertzLoop::integralErrorWarning) {
    return true;
  }
  return false;
}

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
  latestTimestamp.raiseLowerHalf(micros());

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
    if (iterationID == 1) {
      integrationTimestamp2 = latestTimestamp;
    }
    if (iterationID == 2) {
      integrationTimestamp3 = latestTimestamp;
    }

    int64_t interval = latestTimestamp.getLongValue() - previousTimestamp.getLongValue();
    int64_t differentialError = interval - period;

    int64_t actualIntegrated = latestTimestamp.getLongValue() - integrationStartTimestamp.getLongValue();
    int64_t expectedIntegrated = int64_t(iterationID) * period;
    int64_t integralError = actualIntegrated - expectedIntegrated;

    if (enableFatalErrors) {
      if (abs(differentialError) > differentialErrorFatal) {
        throwError(
          "Differential error was too large.",
          period,
          interval,
          differentialError);
        return;
      }
      
      if (abs(integralError) > integralErrorFatal) {
        throwError(
          "Integral error was too large.",
          expectedIntegrated,
          actualIntegrated,
          integralError);
        return;
      }      
    }

    if (enableWarnings) {
      if (shouldWarn(differentialError, integralError)) {
        uint64_t absoluteTime = latestTimestamp.getLongValue();
        uint32_t relativeIterationID = iterationID;
        relativeIterationID -= Application::state.modeStartIterationID;
        
        Log::writeValuesWithFlags(
          7, // flags
          // Log::encodeRawBits(absoluteTime & 0xFFFFFF),
          // Log::encodeRawBits(iterationID),
          // Log::encodeRawBits(relativeIterationID),
          Log::encodeRawBits(integrationStartTimestamp.lowerHalf),
          Log::encodeRawBits(integrationTimestamp2.lowerHalf),
          Log::encodeRawBits(integrationTimestamp3.lowerHalf),
          Log::encodeRawBits(interval),
          Log::encodeRawBits(integralError));
      }
    }
  }

  loopBody();

  iterationID += 1;
}

void _kilohertzLoopBodyOuter() {
  KilohertzLoop::_kilohertzLoopBodyInner();
}

void KilohertzLoop::initialize(
  teensy::inplace_function<void(void), 16> loopBody
) {
  KilohertzLoop::loopBody = loopBody;

  uint32_t timestamp = micros();
  startTimestamp.raiseLowerHalf(timestamp);
  previousTimestamp.raiseLowerHalf(timestamp);
  latestTimestamp.raiseLowerHalf(timestamp);
  integrationStartTimestamp = Timestamp();
  iterationID = 0;

  timer.priority(0);
  timer.begin(_kilohertzLoopBodyOuter, period);
}

void KilohertzLoop::throwError(
  const char *cString, 
  int64_t number1,
  int64_t number2,
  int64_t number3
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