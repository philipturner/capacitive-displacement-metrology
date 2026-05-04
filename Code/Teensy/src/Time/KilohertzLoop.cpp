#include <Arduino.h>
#include "KilohertzLoop.h"

void _kilohertzLoopBody() {
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
  
  uint32_t timestamp = micros();
  KilohertzLoop::startTimestamp = timestamp;
  KilohertzLoop::previousTimestamp = timestamp;
  KilohertzLoop::latestTimestamp = timestamp;

  KilohertzLoop::timer.begin(_kilohertzLoopBody, period);
}