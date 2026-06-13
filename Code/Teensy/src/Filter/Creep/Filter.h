#pragma once

#include "Queue.h"

namespace Creep {
  struct Filter {
    float2 previousStimulus = float2(0);
    float2 currentCreepRate = float2(0);
    float2 futureAccumulatedDrift = float2(0);

    Queue queues[Settings::queueCount];
    
    Filter();
    Filter(bool notDefaultConstructor);
    void forwardState() const;
    void update(float2 stimulus);

  private:
    float2 shiftSampleTimes();
    void updateCreepRate(float2 accumulator);
    void updateQueues();
  };
};
