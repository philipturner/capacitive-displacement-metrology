#include "Filter.h"

#include "Diagnostics/Log.h"
#include <Arduino.h>

using namespace Creep;

Filter::Filter() {

}

Filter::Filter(bool notDefaultConstructor) {
  for (uint32_t queueID = 0; queueID < Settings::queueCount; ++queueID) {
    uint32_t shiftAmount = (Settings::queueCount - 1) - queueID;
    uint32_t maxTime = Settings::logScaleResolution * (1 << shiftAmount);

    queues[queueID] = Queue(float(maxTime));
  }
}

void Filter::forwardState() const {
  Log::writeValuesWithFlags(
    /*flags=*/6,
    Settings::creepConstants.x,
    Settings::creepConstants.y,
    futureAccumulatedDrift.x,
    futureAccumulatedDrift.y);
}

void Filter::update(float2 stimulus) {
  // Responding to the DAC updates from the current iteration.
  Sample sample;
  sample.dV = stimulus + previousStimulus * -1;
  sample.time = 0;
  sample.queueTime = 0;
  previousStimulus = stimulus;

  uint32_t queueID = Settings::queueCount - 1;
  queues[queueID].insert(sample);

  // Preparing the state for the next loop iteration (don't access these
  // variables any more during the calling iteration).
  float2 accumulator = shiftSampleTimes();
  updateCreepRate(accumulator);
  updateQueues();

  futureAccumulatedDrift += currentCreepRate;
}

float2 Filter::shiftSampleTimes() {
  float2 accumulator = float2(0);
  for (uint32_t queueID = 0; queueID < Settings::queueCount; ++queueID) {
    uint32_t startIndex = queues[queueID].startIndex;
    uint32_t endIndex = queues[queueID].endIndex;
    for (uint32_t sampleID = startIndex; sampleID < endIndex; ++sampleID) {
      Sample sample = queues[queueID][sampleID];
      sample.time += 1;
      sample.queueTime += 1;
      queues[queueID][sampleID] = sample;

      float dt = sample.time;
      float dtInv = 1 / dt;
      float sampleCount = Settings::supersamplingRate * dtInv;

      if (sampleCount <= 1) {
        accumulator += sample.dV * dtInv;
      } else {
        float loopSize = ceil(sampleCount);
        float loopSizeInv = 1 / loopSize;
        float localAccumulator = 0;

        for (float i = 0; i < loopSize; ++i) {
          float offset = i * loopSizeInv;
          localAccumulator += 1 / (dt + offset);
        }
        localAccumulator *= loopSizeInv;

        accumulator += sample.dV * localAccumulator;
      }
    }
  }
  return accumulator;
}

void Filter::updateCreepRate(float2 accumulator) {
  float2 creepConstants = Settings::creepConstants * (1 / M_LN10);
  currentCreepRate = accumulator * creepConstants;
}

void Filter::updateQueues() {
  uint32_t removesDone = 0;
  uint32_t maxQueueID = Settings::queueCount - 1;
  for (int32_t queueID = maxQueueID; queueID >= 0; --queueID) {
    bool ready = queues[queueID].hasReadySample();
    if (!ready) {
      continue;
    }

    Sample removed = queues[queueID].removeReady();

    if (queueID > 0) {
      queues[queueID].insert(removed);
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