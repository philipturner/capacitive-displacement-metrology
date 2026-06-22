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
    void resetDrift();
    float2 getDriftCorrection() const;

    // This must be added to the stimulus before entering into 'update', which
    // will subtract it before storing the voltage in the history.
    void setEarlyScaleCorrection(float2 stimulus);

    float2 earlyScaleCorrection = float2(0);  
    float2 scaleCorrection = float2(0);
    float2 futureAccumulatedDrift = float2(0);
    
  private:
    float2 shiftSampleTimes();
    void updateCreepRate(float2 accumulator);
    void updateQueues();
  };
};
