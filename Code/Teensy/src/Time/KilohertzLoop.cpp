#include "KilohertzLoop.h"

#include "Application/Application.h"
#include "Diagnostics/ErrorMessage.h"
#include "Diagnostics/Log.h"
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

// Integral error as a function of start time % loop period, with the costly
// creep filter enabled.
//
// When sampling every 1997 iterations, error alternates between two values
// every ~22 samples.
//
// 50000 - -1 or -10 (imaging), 0 or -5 (idle)
// 50001 - -2 or -11 (imaging), 0 or -6 (idle)
// 50002 - -3 or -12 (imaging), 0 or -7 (idle)
// 50003 - -4 or -13 (imaging), 0 or -8 (idle)
// 50004 - -5 or -14 (imaging), -1 or -9 (idle)
// 50005 - 0 or -7 (imaging), 0 or -2 (idle)
// 50006 - 0 or -7 (imaging), 0 or -3 (idle)
// 50008 - -1 or -10 (imaging), 0 or -5 (idle)
// 50010 - -3 or -12 (imaging), 0 or -7 (idle)
// 50012 - -5 or -14 (imaging), -1 or -9 (idle)

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
  
  if (iterationID == 0) {
    integrationStartTimestamp = latestTimestamp;
  } else {
    int64_t interval = latestTimestamp.getLongValue() - previousTimestamp.getLongValue();
    int64_t differentialError = interval - period;

    int64_t actualIntegrated = latestTimestamp.getLongValue() - integrationStartTimestamp.getLongValue();
    int64_t expectedIntegrated = int64_t(iterationID) * period;
    int64_t integralError = actualIntegrated - expectedIntegrated;

    if (enableFatalErrors) {
      if (abs(differentialError) >= differentialErrorFatal) {
        throwError(
          "Differential error was too large.",
          period,
          interval,
          differentialError);
        return;
      }
      
      if (abs(integralError) >= integralErrorFatal) {
        throwError(
          "Integral error was too large.",
          expectedIntegrated,
          actualIntegrated,
          integralError);
        return;
      }      
    }

    if (enableWarnings) {
      if (abs(differentialError) >= KilohertzLoop::differentialErrorWarning ||
          abs(integralError) >= KilohertzLoop::integralErrorWarning)
      {
        uint32_t relativeIterationID = iterationID;
        relativeIterationID -= Application::state.modeStartIterationID;
        
        Log::writeValuesWithFlags(
          7, // flags
          Log::encodeRawBits(latestTimestamp.lowerHalf),
          Log::encodeRawBits(iterationID),
          Log::encodeRawBits(relativeIterationID),
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