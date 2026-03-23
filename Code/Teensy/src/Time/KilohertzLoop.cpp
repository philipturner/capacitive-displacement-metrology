#include <Arduino.h>
#include "KilohertzLoop.h"

void _kilohertzLoopBody() {
  if (KilohertzLoop::lock) {
    // Never encountered this after about a minute of testing,
    // although the code guarded by the lock was very small.
    //
    // You must include the 20 ms delay at the start of the
    // any asynchronous loop that grabs the lock. Otherwise,
    // this early return will get hit roughly 10% of the time.
    return;
  }

  KilohertzLoop::previousTimestamp = KilohertzLoop::latestTimestamp;
  KilohertzLoop::latestTimestamp = micros();
  KilohertzLoop::loopBody();
}

void KilohertzLoop::initialize(
  teensy::inplace_function<void(void), 16> loopBody,
  uint32_t period
) {
  KilohertzLoop::loopBody = loopBody;
  KilohertzLoop::period = period;
  KilohertzLoop::lock = false;

  uint32_t timestamp = micros();
  KilohertzLoop::startTimestamp = timestamp;
  KilohertzLoop::previousTimestamp = timestamp;
  KilohertzLoop::latestTimestamp = timestamp;

  KilohertzLoop::timer.begin(_kilohertzLoopBody, period);
}