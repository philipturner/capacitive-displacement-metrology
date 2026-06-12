#pragma once

#include "Queue.h"

namespace Creep {
  struct Filter {
    bool creepRateUpdated = false;
    float2 currentCreepRate = float2(-1000);
    float2 accumulatedDrift = float2(0);
    float2 currentStimulus = float2(0);

    Queue queues[Settings::queueCount];

    Filter();
    Filter(bool notDefaultConstructor);

    void forwardState();

  private:
    void shiftDelayLine();
  };
};
