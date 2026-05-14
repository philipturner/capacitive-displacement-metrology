#include "CapacitanceTracker.h"

#include "../Time/KilohertzLoop.h"
#include <Arduino.h>

CapacitanceTracker::CapacitanceTracker() {

}

CapacitanceTracker::CapacitanceTracker(bool notDefaultConstructor) {
  startIterationID = KilohertzLoop::iterationID;
  startTrueTime = micros();
  resetIntegrationVariables();
}

void CapacitanceTracker::resetIntegrationVariables() {
  zeroCrossingStartID = KilohertzLoop::iterationID;
  zeroCrossingEndID = -1;
  sineSquaredAccumulator = 0;
  cosineSquaredAccumulator = 0;
  rmsCurrentSampleCount = 0;
}

CapacitanceTracker::State 
CapacitanceTracker::getState(uint32_t iterationID) {
  if (wavePeriod % KilohertzLoop::period != 0) {
    Serial.println("Capacitance wave not divisible by loop period.");
    exit(0);
  }

  uint32_t iterationsPerWave = wavePeriod / KilohertzLoop::period;
  
}

void CapacitanceTracker::update(
  float &capacitance, 
  float &phaseShift
) {

}