#include "Queue.h"

#include <Arduino.h>

using namespace Creep;

Queue::Queue() {

}

Queue::Queue(float maxTime) {
  this->maxTime = maxTime;
}

void Queue::insert(Sample sample) {
  if (endIndex - startIndex >= capacity) {
    // Serial.println("Exceeded capacity of ring buffer.");
    // exit(0);
    startIndex += 1;
  }

  (*this)[endIndex] = sample;
  endIndex += 1;
}

Sample Queue::removeReady() {
  auto sample0 = (*this)[startIndex + 0];
  auto sample1 = (*this)[startIndex + 1];
  startIndex += 2;

  return Sample(sample0, sample1);
}