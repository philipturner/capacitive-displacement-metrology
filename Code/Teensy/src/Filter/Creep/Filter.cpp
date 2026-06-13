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
  uint32_t buffer[200];

  uint32_t accumulator = 0;
  for (uint32_t queueID = 0; queueID < Settings::queueCount; ++queueID) {
    
    // uint32_t startIndex = queues[queueID].startIndex;
    // uint32_t endIndex = queues[queueID].endIndex;

    // The indices are spaced by 100
    // Nothing happens during inner loop: 258 ns
    // 50 iterations of integer add: 454 ns
    // 100 iterations of integer add: 620 ns
    // 100 iterations reading from stack buffer: 959 ns
    // 100 iterations with indices known at compile time: 613 ns
    // with integer modulus Queue::capacity: 2298 ns
    // changing Queue::capacity to 128: 1528 ns
    // not doing the above, but randomly changing Queue.data to have 128 size:
    // 958 -> 1286 ns
    // changing it to have size 500:
    // 958 ns
    // 511-513: 1284 ns
    // anything 510 and below: 956 ns
    auto queue = queues[queueID];
    uint32_t startIndex = queue.startIndex;
    uint32_t endIndex = queue.endIndex;
    for (uint32_t sampleID = startIndex; sampleID < endIndex; ++sampleID) {
    // for (uint32_t sampleID = 0; sampleID < 100; ++sampleID) {
      // Sample sample = queue.data[sampleID % 4];
      // accumulator += float(1 / (sample.time + 1));

      //float time = buffer[(sampleID - startIndex) % 4];
      //accumulator += buffer[sampleID % 64]; // float(1 / (time + 1));
      // accumulator += buffer[sampleID % 64];
      accumulator += buffer[sampleID % 128];

      /*
      sample.time += 1;
      sample.queueTime += 1;
      queues[queueID][sampleID] = sample;

      float dt = sample.time;
      float dtInv = 1 / dt;
      float sampleCount = Settings::supersamplingRate * dtInv;
      */

      //if (sampleCount <= 1) {
      //accumulator += sample.dV * dtInv;
        /*
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
        */
    }
  }
  return float2(float(accumulator));
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