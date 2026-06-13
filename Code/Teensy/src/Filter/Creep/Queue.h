#pragma once

#include "Sample.h"

namespace Creep {
  struct Queue {
    // minimum required: logScaleResolution + 1
    static constexpr uint32_t queueCapacity = 8;
    static constexpr uint32_t logScaleResolution = 4;
    static constexpr uint32_t queueCount = 33;

    // This is stored in RAM1, and memory bandwidth does not contribute to the
    // performance degradation when reading from this.
    static inline Sample buffer[queueCapacity * queueCount];

    uint32_t bufferOffset;
    uint32_t maxTime;
    uint32_t startIndex = 0;
    uint32_t endIndex = 0;

    Queue();
    Queue(uint32_t id, uint32_t maxTime);

    Sample get(uint32_t index) const {
      uint32_t slotID = bufferOffset + (index % queueCapacity);
      return Queue::buffer[slotID];
    }

    void set(uint32_t index, Sample input) {
      uint32_t slotID = bufferOffset + (index % queueCapacity);
      Queue::buffer[slotID] = input;
    }

    void insert(Sample sample);

    bool hasReadySample(uint32_t timeOffset) const {
      if (endIndex - startIndex < 2) {
        return false;
      }

      uint32_t queueTime0 = get(startIndex + 0).queueTime;
      uint32_t queueTime1 = get(startIndex + 1).queueTime;
      uint32_t queueTimeCombined = (queueTime0 + queueTime1) / 2;

      uint32_t dt = timeOffset - queueTimeCombined;
      return (dt > maxTime);
    }

    Sample removeReady();
  };
};