#include "CapacitanceTracker.h"

#include "../Time/KilohertzLoop.h"
#include <Arduino.h>

CapacitanceTracker::CapacitanceTracker() {

}

CapacitanceTracker::CapacitanceTracker(bool notDefaultConstructor) {
  startIterationID = KilohertzLoop::iterationID;
  startTrueTime = micros();
  previousState = State::waiting;
  currentState = State::waiting;
}

CapacitanceTracker::State 
CapacitanceTracker::getState(uint32_t iterationID) {
  if (wavePeriod % KilohertzLoop::period != 0) {
    Serial.println("Capacitance wave period not divisible by loop period.");
    exit(0);
  }

  uint32_t itersPerWave = wavePeriod / KilohertzLoop::period;
  uint32_t measuringTransition = waveCountPre * itersPerWave;
  uint32_t finishedTransition = (waveCountPre + waveCountPost) * itersPerWave;

  uint32_t iterationDelta = iterationID - startIterationID;
  if (iterationDelta < measuringTransition) {
    return State::waiting;
  } else if (iterationDelta < finishedTransition) {
    return State::measuring;
  } else {
    return State::finished;
  }
}

CapacitanceTracker::State
CapacitanceTracker::getCurrentState() const {
  return currentState;
}

void CapacitanceTracker::update(
  float &capacitance, 
  float &phaseShift
) {
  previousState = currentState;
  currentState = getState(KilohertzLoop::iterationID);

  updateReferenceSignals();

  if (previousState == State::waiting && currentState == State::measuring) {
    zeroCrossingStartID = KilohertzLoop::iterationID;
  }

  if (previousState == State::measuring && currentState == State::finished) {
    uint32_t itersPerWave = wavePeriod / KilohertzLoop::period;
    uint32_t itersPerMeasurement = waveCountPost * itersPerWave;
    if (lockInSampleCount != itersPerMeasurement) {
      Serial.println("Unexpected behavior in capacitance measurement");
      Serial.println(lockInSampleCount);
      Serial.println(itersPerMeasurement);
      exit(0);
    }

    float n = float(lockInSampleCount);
    float sineSquaredMixed = sineSquaredAccumulator / n;
    float cosineSquaredMixed = cosineSquaredAccumulator / n;
    float signalMax = sqrt(sineSquaredMixed + cosineSquaredMixed) * 2;

    float waveFrequency = float(1e6) / float(wavePeriod);
    float slewRateMax = stimulusAmplitude * 2 * M_PI * waveFrequency;
    capacitance = signalMax / slewRateMax;

    // sqrt(X^2 + Y^2) != (signal's sine wave amplitude) / 2
    //
    // This is a confirmed error. I tested it with a simulated waveform
    // from 7.00 fF capacitance and the bias voltage, but the measured
    // capacitance was 9.91 fF (a factor of 1.416 higher).
    capacitance *= M_SQRT1_2;

    if (zeroCrossingEndID < zeroCrossingStartID) {
      // This should never happen, but theoretically a spurious signal could
      // disrupt the amplifier. Handle this error gracefully.
      phaseShift = -1000;
    } else {
      float timeLag = float(zeroCrossingEndID - zeroCrossingStartID);
      timeLag *= float(KilohertzLoop::period);
      timeLag -= float(wavePeriod);

      float servoLoopLag = 0;
      servoLoopLag += 2.4; // DAC
      servoLoopLag += 10; // ADC 100 kSPS sampling
      servoLoopLag += 29; // 3 poles (10 kHz, 24 kHz, 24 kHz)
      timeLag -= servoLoopLag;

      float relativeTimeLag = timeLag / float(wavePeriod);
      phaseShift = -relativeTimeLag * 360;
      if (phaseShift > 180) {
        phaseShift -= 360;
      }
    }
  }
}

void CapacitanceTracker::updateReferenceSignals() {
  uint32_t elapsedTime = micros() - startTrueTime;
  uint32_t phase = elapsedTime % wavePeriod;

  float phaseNormalized = float(phase) / float(wavePeriod);
  referenceSine = sin(phaseNormalized * 2 * M_PI);
  referenceCosine = cos(phaseNormalized * 2 * M_PI);
}

float CapacitanceTracker::getBiasVoltage() const {
  return stimulusAmplitude * referenceSine;
}

void CapacitanceTracker::integrate(float current) {
  if (currentState == State::measuring) {
    // This relies on the fact that average current is zero. When the tunneling
    // current is established, the existing algorithm cannot correctly compute
    // the phase.
    if (previousCurrent < 0 && current > 0) {
      if (zeroCrossingEndID == -1) {
        zeroCrossingEndID = KilohertzLoop::iterationID;
      }
    }

    float sineMixed = referenceSine * current;
    float cosineMixed = referenceCosine * current;
    sineSquaredAccumulator += sineMixed * sineMixed;
    cosineSquaredAccumulator += cosineMixed * cosineMixed;
    lockInSampleCount += 1;
  }

  previousCurrent = current;
}