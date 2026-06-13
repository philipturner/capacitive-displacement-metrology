#include "Queue.h"

#include <Arduino.h>

using namespace Creep;

Queue::Queue() {

}

Queue::Queue(uint32_t id, uint32_t maxTime) {
  this->bufferOffset = id * Settings::queueCapacity;
  this->maxTime = maxTime;
}

void Queue::insert(Sample sample) {
  uint32_t trueCapacity = Settings::logScaleResolution + 1;
  if (endIndex - startIndex >= trueCapacity) {
    Serial.println("Exceeded capacity of ring buffer.");
    exit(0);
  }

  set(endIndex, sample);
  endIndex += 1;
}

Sample Queue::removeReady() {
  auto sample0 = get(startIndex + 0);
  auto sample1 = get(startIndex + 1);
  startIndex += 2;

  return Sample(sample0, sample1);
}