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
}

void Filter::forwardState() const {
  Log::writeValuesWithFlags(
    /*flags=*/6,
    creepConstants.x,
    creepConstants.y,
    futureAccumulatedDrift.x,
    futureAccumulatedDrift.y);
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
      float dtInv = 1 / dt;

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
      float localAccumulator = 0;
      if (dt >= float(LookupTable::supersamplingRate)) {
        localAccumulator = dtInv;
      } else {
        float sampleCount = float(LookupTable::supersamplingRate) * dtInv;
        float loopSize = ceil(sampleCount);

        for (float i = 0; i < loopSize; ++i) {
          float denominator = dt * loopSize + i;
          localAccumulator += 1 / denominator;
        }
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