#pragma once

#include "Command/Parsing/Command.h"
#include "LookupTable.h"
#include "Queue.h"

namespace Creep {
  struct Filter {
    float2 creepConstants = float2(0);
    float2 previousStimulus = float2(0);
    float2 currentCreepRate = float2(0);
    float2 futureAccumulatedDrift = float2(0);

    Queue queues[Queue::queueCount];
    LookupTable lookupTable;
    uint32_t timeOffset = 0;
    
    Filter();
    Filter(bool notDefaultConstructor);
    void forwardSettings() const;
    void updateSettings(Command command);
    void update(float2 stimulus);

  private:
    float2 shiftSampleTimes();
    void updateCreepRate(float2 accumulator);
    void updateQueues();
  };
};
