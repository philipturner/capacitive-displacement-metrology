#include "Filter.h"

#include "Diagnostics/Log.h"
#include "Filter/Creep/Settings.h"
#include <Arduino.h>

using namespace Creep;

Filter::Filter() {

}

Filter::Filter(bool notDefaultConstructor) {
  for (uint32_t queueID = 0; queueID < Queue::queueCount; ++queueID) {
    uint32_t shiftAmount = (Queue::queueCount - 1) - queueID;
    uint32_t maxTime = Queue::logScaleResolution * (1 << shiftAmount);

    queues[queueID] = Queue(queueID, maxTime);
  }

  lookupTable = LookupTable(true);
}

float getScaleChange() {
  float loopPeriod = float(KilohertzLoop::period) * 1e-6f;
  return log10f(0.01f) - log10f(loopPeriod);
}
inline float scaleChange = getScaleChange();

void Filter::update(float2 stimulus) {
  // TODO: Subtract away the early scale correction.
  float2 trueStimulus = stimulus - earlyScaleCorrection;

  // Responding to the DAC updates from the current iteration.
  Sample sample;
  sample.dV = trueStimulus - previousStimulus;
  sample.trueTimeOffset = 0;
  sample.queueTime = timeOffset;
  previousStimulus = trueStimulus;

  uint32_t queueID = Queue::queueCount - 1;
  queues[queueID].insert(sample);

  // Preparing the state for the next loop iteration (don't access these
  // variables any more during the calling iteration).
  float2 accumulator = shiftSampleTimes();
  updateCreepRate(accumulator);
  updateQueues();

  earlyScaleCorrection = float2(0);
  scaleCorrection -= sample.dV * Settings::creepConstants * scaleChange;
  futureAccumulatedDrift += currentCreepRate;
}

void Filter::resetDrift() {
  scaleCorrection = float2(0);
  futureAccumulatedDrift = float2(0);
}

float2 Filter::getDriftCorrection() const {
  return scaleCorrection + futureAccumulatedDrift;
}

void Filter::setEarlyScaleCorrection(float2 stimulus) {
  float2 dV = stimulus - previousStimulus;
  earlyScaleCorrection = -1 * dV * Settings::creepConstants * scaleChange;
}

float2 Filter::shiftSampleTimes() {
  timeOffset += 1;

  float2 accumulator = float2(0);
  for (uint32_t queueID = 0; queueID < Queue::queueCount; ++queueID) {
    Queue queue = queues[queueID];
    uint32_t startIndex = queue.startIndex;
    uint32_t endIndex = queue.endIndex;

    for (uint32_t sampleID = startIndex; sampleID < endIndex; ++sampleID) {
      Sample sample = queue.get(sampleID);
      
      float dt = float(timeOffset - sample.queueTime);
      dt -= sample.trueTimeOffset;

      float localAccumulator;
      if (dt >= float(LookupTable::supersamplingRate)) {
        localAccumulator = 1.0f / dt;
      } else {
        uint32_t binID = lookupTable.getBinID(dt);
        localAccumulator = lookupTable.bins[binID];
      }
      accumulator += sample.dV * localAccumulator;
    }
  }
  return float2(accumulator);
}

void Filter::updateCreepRate(float2 accumulator) {
  float2 creepConstants = Settings::creepConstants;
  currentCreepRate = accumulator * creepConstants * float(1 / M_LN10);
}

void Filter::updateQueues() {
  uint32_t removesDone = 0;
  uint32_t maxQueueID = Queue::queueCount - 1;
  for (int32_t queueID = maxQueueID; queueID >= 0; --queueID) {
    bool ready = queues[queueID].hasReadySample(timeOffset);
    if (!ready) {
      continue;
    }

    Sample removed = queues[queueID].removeReady();

    if (queueID > 0) {
      queues[queueID - 1].insert(removed);
    }

    removesDone += 1;
  }

  // If logScaleResolution is divisible by 2, removesDone mysteriously never
  // exceeds 1 on any given iteration.
  if (removesDone > 1) {
    Serial.println("More than one remove happened.");
    exit(0);
  }
}