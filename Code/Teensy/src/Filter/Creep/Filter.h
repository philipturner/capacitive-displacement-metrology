#pragma once

#include "Queue.h"

namespace Creep {
  struct Filter {
    bool creepRateUpdated = true;
    float2 currentCreepRate = float2(0);
    float2 accumulatedDrift = float2(0);
    float2 currentStimulus = float2(0);

    Queue queues[Settings::queueCount];

    Filter();
    Filter(bool notDefaultConstructor);
    void forwardState() const;



    static void runTestProgram();

  private:
    void shiftDelayLine();
  };
};
