#include "Filter.h"

#include "Diagnostics/Log.h"
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

void Filter::forwardState() const {
  Log::writeValuesWithFlags(
    /*flags=*/6,
    creepConstants.x,
    creepConstants.y,
    futureAccumulatedDrift.x,
    futureAccumulatedDrift.y);
}

void Filter::registerSettingsCommand(Command command) {
  // TODO: Implement

  forwardState();
}

void Filter::update(float2 stimulus) {
  // Responding to the DAC updates from the current iteration.
  Sample sample;
  sample.dV = stimulus + previousStimulus * -1;
  sample.trueTimeOffset = 0;
  sample.queueTime = timeOffset;
  previousStimulus = stimulus;

  uint32_t queueID = Queue::queueCount - 1;
  queues[queueID].insert(sample);

  // Preparing the state for the next loop iteration (don't access these
  // variables any more during the calling iteration).
  float2 accumulator = shiftSampleTimes();
  updateCreepRate(accumulator);
  updateQueues();

  futureAccumulatedDrift += currentCreepRate;
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
        localAccumulator = 1 / dt;
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
  currentCreepRate = accumulator * creepConstants * (1 / M_LN10);
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