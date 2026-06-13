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

    queues[queueID] = Queue(queueID, maxTime);
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

// Performance data
// 6000 ns for the first version of the code
//
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
float2 Filter::shiftSampleTimes() {
  float2 accumulator = float2(0);
  for (uint32_t queueID = 0; queueID < Settings::queueCount; ++queueID) {
    //uint32_t bufferOffset = queueID * Settings::queueCapacity;
    uint32_t startIndex = queues[queueID].startIndex;
    uint32_t endIndex = queues[queueID].endIndex;
    for (uint32_t sampleID = startIndex; sampleID < endIndex; ++sampleID) {
      /*
      uint32_t slotID = bufferOffset + (sampleID % Settings::queueCapacity);
      float time = Queue::buffer2[slotID];
      float queueTime = Queue::buffer3[slotID];
      time += 1;
      queueTime += 1;
      Queue::buffer2[slotID] = time;
      Queue::buffer3[slotID] = queueTime;
      */

      Sample sample = queues[queueID].get(sampleID);
      sample.time += 1;
      sample.queueTime += 1;
      queues[queueID].set(sampleID, sample);

      float dt = sample.time;
      float dtInv = 1 / dt;
      float sampleCount = Settings::supersamplingRate * dtInv;

      // disparity from removing supersampling:
      //
      // expected:
      // t:  194 | V: -0.809017 | x: -0.005817 | x: -0.814834 | dx: 0.000000 | dx: -0.000262 | 
      // t:  195 | V: -0.707107 | x: -0.005897 | x: -0.713004 | dx: 0.000000 | dx: -0.000080 | 
      // t:  196 | V: -0.587786 | x: -0.005800 | x: -0.593586 | dx: 0.000000 | dx: 0.000097 | 
      // t:  197 | V: -0.453991 | x: -0.005522 | x: -0.459512 | dx: 0.000000 | dx: 0.000279 | 
      // t:  198 | V: -0.309017 | x: -0.005072 | x: -0.314089 | dx: 0.000000 | dx: 0.000450 | 
      // t:  199 | V: -0.156435 | x: -0.004463 | x: -0.160898 | dx: 0.000000 | dx: 0.000609 | 
      //
      // actual:
      // t: 194 | V: -0.809017 | x: -0.007299 | x: -0.816316 | dx: 0.000000 | dx: -0.000196 | 
      // t: 195 | V: -0.707107 | x: -0.007278 | x: -0.714384 | dx: 0.000000 | dx: 0.000022 | 
      // t: 196 | V: -0.587785 | x: -0.007043 | x: -0.594828 | dx: 0.000000 | dx: 0.000235 | 
      // t: 197 | V: -0.453990 | x: -0.006596 | x: -0.460587 | dx: 0.000000 | dx: 0.000447 | 
      // t: 198 | V: -0.309017 | x: -0.005953 | x: -0.314970 | dx: 0.000000 | dx: 0.000643 | 
      // t: 199 | V: -0.156434 | x: -0.005129 | x: -0.161563 | dx: 0.000000 | dx: 0.000824 | 
      //
      // try a lookup table approach
      float localAccumulator;
      if (sampleCount <= 1) {
        localAccumulator = dtInv;
      } else {
        float loopSize = ceil(sampleCount);
        float loopSizeInv = 1 / loopSize;
        localAccumulator = 0;

        for (float i = 0; i < loopSize; ++i) {
          float offset = i * loopSizeInv;
          localAccumulator += 1 / (dt + offset);
        }
        localAccumulator *= loopSizeInv;
      }

      /*
      float dVx = Queue::buffer0[slotID];
      float dVy = Queue::buffer1[slotID];
      accumulator.x += dVx * localAccumulator;
      accumulator.y += dVy * localAccumulator;
      */
     accumulator += sample.dV * localAccumulator;
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