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

void Filter::forwardState() {
  Log::writeValuesWithFlags(
    /*flags=*/6,
    Settings::creepConstants.x,
    Settings::creepConstants.y,
    accumulatedDrift.x,
    accumulatedDrift.y);
}

void Filter::shiftDelayLine() {
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