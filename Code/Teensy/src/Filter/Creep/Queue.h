#pragma once

#include "Sample.h"
#include "Settings.h"

/*
expected:
t: 19994 | V: -0.809017 | x: 0.017565 | x: -0.791452 | dx: 0.000000 | dx: -0.000221 | 
t: 19995 | V: -0.707107 | x: 0.017525 | x: -0.689582 | dx: 0.000000 | dx: -0.000040 | 
t: 19996 | V: -0.587786 | x: 0.017660 | x: -0.570126 | dx: 0.000000 | dx: 0.000135 | 
t: 19997 | V: -0.453991 | x: 0.017977 | x: -0.436014 | dx: 0.000000 | dx: 0.000317 | 
t: 19998 | V: -0.309017 | x: 0.018463 | x: -0.290554 | dx: 0.000000 | dx: 0.000486 | 
t: 19999 | V: -0.156435 | x: 0.019107 | x: -0.137327 | dx: 0.000000 | dx: 0.000644 | 

Teensy with no degradation of precision:
t: 19994 | V: -0.809017 | x: 0.017561 | x: -0.791456 | dx: 0.000000 | dx: -0.000221 | 
t: 19995 | V: -0.707107 | x: 0.017521 | x: -0.689586 | dx: 0.000000 | dx: -0.000040 | 
t: 19996 | V: -0.587785 | x: 0.017656 | x: -0.570129 | dx: 0.000000 | dx: 0.000135 | 
t: 19997 | V: -0.453990 | x: 0.017973 | x: -0.436017 | dx: 0.000000 | dx: 0.000317 | 
t: 19998 | V: -0.309017 | x: 0.018459 | x: -0.290558 | dx: 0.000000 | dx: 0.000486 | 
t: 19999 | V: -0.156434 | x: 0.019104 | x: -0.137331 | dx: 0.000000 | dx: 0.000644 | 

quantizing within a factor of 100:
t: 19994 | V: -0.809017 | x: 0.018438 | x: -0.790579 | dx: 0.000000 | dx: -0.000221 | 
t: 19995 | V: -0.707107 | x: 0.018397 | x: -0.688709 | dx: 0.000000 | dx: -0.000040 | 
t: 19996 | V: -0.587785 | x: 0.018532 | x: -0.569253 | dx: 0.000000 | dx: 0.000135 | 
t: 19997 | V: -0.453990 | x: 0.018849 | x: -0.435142 | dx: 0.000000 | dx: 0.000316 | 
t: 19998 | V: -0.309017 | x: 0.019335 | x: -0.289682 | dx: 0.000000 | dx: 0.000486 | 
t: 19999 | V: -0.156434 | x: 0.019979 | x: -0.136455 | dx: 0.000000 | dx: 0.000644 |

dynamic quantization:
1000x for maxTime < 500
10x for maxTime > 500
t: 19994 | V: -0.809017 | x: 0.017460 | x: -0.791557 | dx: 0.000000 | dx: -0.000221 | 
t: 19995 | V: -0.707107 | x: 0.017420 | x: -0.689687 | dx: 0.000000 | dx: -0.000040 | 
t: 19996 | V: -0.587785 | x: 0.017555 | x: -0.570230 | dx: 0.000000 | dx: 0.000135 | 
t: 19997 | V: -0.453990 | x: 0.017872 | x: -0.436119 | dx: 0.000000 | dx: 0.000317 | 
t: 19998 | V: -0.309017 | x: 0.018358 | x: -0.290659 | dx: 0.000000 | dx: 0.000486 | 
t: 19999 | V: -0.156434 | x: 0.019003 | x: -0.137432 | dx: 0.000000 | dx: 0.000644 | 
*/

namespace Creep {
  struct Queue {
    static inline float buffer0[Settings::queueCapacity * Settings::queueCount];
    static inline float buffer1[Settings::queueCapacity * Settings::queueCount];
    static inline float buffer2[Settings::queueCapacity * Settings::queueCount];
    static inline uint32_t buffer3[Settings::queueCapacity * Settings::queueCount];

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

    float getQuantizationFactor() const {
      if (maxTime < 500) {
        return 1000;
      } else {
        return 10;
      }
    }

    Sample get(uint32_t index) const {
      uint32_t slotID = bufferOffset + (index % Settings::queueCapacity);

      float queueTimeRounded = float(Queue::buffer3[slotID]) * 0.5;
      float dt = Queue::buffer2[slotID];

      Sample output;
      output.dV.x = Queue::buffer0[slotID];
      output.dV.y = Queue::buffer1[slotID];
      output.time = dt + queueTimeRounded;
      output.queueTime = queueTimeRounded;
      return output;
    }

    void set(uint32_t index, Sample input) {
      uint32_t slotID = bufferOffset + (index % Settings::queueCapacity);

      uint32_t queueTimeInt = uint32_t(input.queueTime * 2);
      float queueTimeRounded = float(queueTimeInt) * 0.5;
      float dt = input.time - queueTimeRounded;

      Queue::buffer0[slotID] = input.dV.x;
      Queue::buffer1[slotID] = input.dV.y;
      Queue::buffer2[slotID] = dt;
      Queue::buffer3[slotID] = uint32_t(input.queueTime * 2);
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