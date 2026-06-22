#pragma once

#include "Command/Parsing/Command.h"
#include "LookupTable.h"
#include "Queue.h"

namespace Creep {
  struct Filter {
    float2 previousStimulus = float2(0);
    float2 currentCreepRate = float2(0);
    
    Queue queues[Queue::queueCount];
    LookupTable lookupTable;
    uint32_t timeOffset = 0;
    
    Filter();
    Filter(bool notDefaultConstructor);
    void update(float2 stimulus);
    void resetError();

    // This must be subtracted from the stimulus before entering into 'update',
    // which will add it before storing the voltage in the history.
    void setEarlyScaleError(float2 stimulus);

    float2 earlyScaleError = float2(0);  
    float2 scaleError = float2(0);
    float2 futureAccumulatedDrift = float2(0);
    
  private:
    float2 shiftSampleTimes();
    void updateCreepRate(float2 accumulator);
    void updateQueues();
  };
};
