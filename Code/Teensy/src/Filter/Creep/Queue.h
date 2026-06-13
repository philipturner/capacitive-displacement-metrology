#pragma once

#include "Sample.h"
#include "Settings.h"

namespace Creep {
  struct Queue {
    static inline Sample dataBuffer[Settings::queueCapacity * Settings::queueCount];

    uint32_t bufferOffset;
    float maxTime;
    uint32_t startIndex = 0;
    uint32_t endIndex = 0;

    Queue();
    Queue(uint32_t id, float maxTime);

    /*
    Sample& operator[](uint32_t index) {
      uint32_t slotID = index % Settings::queueCapacity;
      return Queue::dataBuffer[bufferOffset + slotID];
    }

    const Sample& operator[](uint32_t index) const {
      uint32_t slotID = index % Settings::queueCapacity;
      return Queue::dataBuffer[bufferOffset + slotID];
    }
      */

    Sample get(uint32_t index) const {
      uint32_t slotID = index % Settings::queueCapacity;
      return Queue::dataBuffer[bufferOffset + slotID];
    }

    void set(uint32_t index, Sample x) {
      uint32_t slotID = index % Settings::queueCapacity;
      Queue::dataBuffer[bufferOffset + slotID] = x;
    }

    void insert(Sample sample);

    bool hasReadySample() const {
      if (endIndex - startIndex < 2) {
        return false;
      }

      float queueTime0 = get(startIndex + 0).queueTime;
      float queueTime1 = get(startIndex + 1).queueTime;
      float queueTimeCombined = (queueTime0 + queueTime1) / 2;

      return (queueTimeCombined > maxTime);
    }

    Sample removeReady();
  };
};