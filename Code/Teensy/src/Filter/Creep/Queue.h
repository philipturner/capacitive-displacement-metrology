#pragma once

#include "Sample.h"
#include "Settings.h"

namespace Creep {
  struct Queue {
    static constexpr uint32_t capacity = Settings::logScaleResolution + 1;
    // static constexpr uint32_t capacity = 128;

    float maxTime;
    uint32_t startIndex = 0;
    uint32_t endIndex = 0;
    Sample data[506];

    Queue();
    Queue(float maxTime);

    Sample& operator[](uint32_t index) {
      uint32_t slotID = index % capacity;
      return data[slotID];
    }

    const Sample& operator[](uint32_t index) const {
      uint32_t slotID = index % capacity;
      return data[slotID];
    }

    void insert(Sample sample);

    bool hasReadySample() const {
      if (endIndex - startIndex < 2) {
        return false;
      }

      float queueTime0 = (*this)[startIndex + 0].queueTime;
      float queueTime1 = (*this)[startIndex + 1].queueTime;
      float queueTimeCombined = (queueTime0 + queueTime1) / 2;

      return (queueTimeCombined > maxTime);
    }

    Sample removeReady();
  };
};