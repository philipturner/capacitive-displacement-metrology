#include "CapacitanceTracker.h"

#include "Application/Application.h"
#include "Time/KilohertzLoop.h"
#include <Arduino.h>

CapacitanceTracker::CapacitanceTracker() {

}

CapacitanceTracker::CapacitanceTracker(bool notDefaultConstructor) {
  startIterationID = KilohertzLoop::iterationID;
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

void CapacitanceTracker::update() {
  previousState = currentState;
  currentState = getState(KilohertzLoop::iterationID);

  updateReferenceSignals();

  if (previousState == State::waiting && currentState == State::measuring) {
    zeroCrossingStartID = KilohertzLoop::iterationID;
    zeroCrossingIterations = -2;
  }

  if (previousState == State::measuring) {
    uint32_t itersPerWave = wavePeriod / KilohertzLoop::period;
    uint32_t nextStartID = zeroCrossingStartID + itersPerWave;
    if (KilohertzLoop::iterationID == nextStartID) {
      if (zeroCrossingIterations == -2) {
        // This should never happen, but theoretically a spurious signal
        // could disrupt the amplifier. Handle this error gracefully.
        zeroCrossingFailed = true;
      } else {
        zeroCrossingAccumulator += zeroCrossingIterations;
        zeroCrossingSampleCount += 1;
      }
      zeroCrossingStartID = nextStartID;
      zeroCrossingIterations = -2;
    }
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
    float sineMixed = 2 * sineAccumulator / n;
    float cosineMixed = 2 * cosineAccumulator / n;
    Application::state.diagnostic1 = sineMixed;
    Application::state.diagnostic2 = cosineMixed;

    float signalMax = 0;
    signalMax += sineMixed * sineMixed;
    signalMax += cosineMixed * cosineMixed;
    signalMax = sqrt(signalMax);

    float waveFrequency = float(1e6) / float(wavePeriod);
    float slewRateMax = stimulusAmplitude * 2 * M_PI * waveFrequency;
    Application::state.capacitance = signalMax / slewRateMax;

    // sqrt(X^2 + Y^2) != (signal's sine wave amplitude) / 2
    //
    // This is a confirmed error. I tested it with a simulated waveform
    // from 7.00 fF capacitance and the bias voltage, but the measured
    // capacitance was 9.91 fF (a factor of 1.416 higher).
    // float multiplier = M_SQRT2;
    // Application::state.capacitance *= multiplier;
    Application::state.diagnostic1 *= 1 / slewRateMax;
    Application::state.diagnostic2 *= 1 / slewRateMax;

    if (zeroCrossingFailed) {
      Application::state.phaseShift = -1000;
    } else {
      if (zeroCrossingSampleCount != waveCountPost) {
        Serial.println("Unexpected behavior in phase measurement");
        Serial.println(zeroCrossingSampleCount);
        Serial.println(waveCountPost);
        exit(0);
      }

      float timeLag = zeroCrossingAccumulator;
      timeLag /= float(zeroCrossingSampleCount);
      timeLag *= float(KilohertzLoop::period);
      timeLag -= float(wavePeriod);

      // We need to calibrate this with the actual time lag; it is reading
      // +83° instead of +90° phase shift.
      #if 0
      float servoLoopLag = 0;
      servoLoopLag += 2.4; // DAC sequential update wait time
      servoLoopLag += 3.5; // TIA, 45 kHz pole
      servoLoopLag += 13.3; // ADC suspected 24 kHz, Q = 0.500
      servoLoopLag += 5.0; // ADC conversion time
      servoLoopLag += 5.0; // ADC acquisition time
      servoLoopLag += 15.9; // digital 10 kHz LPF
      timeLag -= servoLoopLag;
      #endif

      float relativeTimeLag = timeLag / float(wavePeriod);
      Application::state.phaseShift = -relativeTimeLag * 360;
    }
  }
}

void CapacitanceTracker::updateReferenceSignals() {
  uint32_t deltaIters = KilohertzLoop::iterationID - startIterationID;
  uint32_t deltaMicros = deltaIters * KilohertzLoop::period;
  uint32_t phase = deltaMicros % wavePeriod;

  float phaseNormalized = float(phase) / float(wavePeriod);
  referenceStimulus = sin(phaseNormalized * 2 * M_PI);

  // 65: -4.3e-12
  // 64: -1.1e-12
  // 63.8: -5e-13, -6.5e-13
  // 63.6: 5e-14
  // 63.4: 6e-13
  // 63: 2e12
  float integrationPhase = float(phase);
  integrationPhase -= 63.6;
  integrationPhase /= float(wavePeriod);

  referenceSine = sin(integrationPhase * 2 * M_PI);
  referenceCosine = cos(integrationPhase * 2 * M_PI);
}

float CapacitanceTracker::getBiasVoltage() const {
  return stimulusAmplitude * referenceStimulus;
}

void CapacitanceTracker::integrate(float current) {
  if (currentState == State::measuring) {
    // This relies on the fact that average current is zero. When the tunneling
    // current is established, the existing algorithm cannot correctly compute
    // the phase.
    if (previousCurrent < 0 && current > 0) {
      if (zeroCrossingIterations == -2) {
        uint32_t iterationID = KilohertzLoop::iterationID;
        zeroCrossingIterations = float(iterationID - zeroCrossingStartID);

        float progress = (0 - previousCurrent) / (current - previousCurrent);
        float correction = -1 * (1 - progress) + 0 * progress;
        zeroCrossingIterations += correction;
      }
    }

    float sineMixed = referenceSine * current;
    float cosineMixed = referenceCosine * current;
    sineSquaredAccumulator += sineMixed * sineMixed;
    cosineSquaredAccumulator += cosineMixed * cosineMixed;
    sineAccumulator += sineMixed;
    cosineAccumulator += cosineMixed;
    lockInSampleCount += 1;
  }

  previousCurrent = current;
}
