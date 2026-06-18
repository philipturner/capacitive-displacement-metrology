#pragma once

#include "Command/Parsing/Command.h"
#include "Time/KilohertzLoop.h"
#include "Util/Vector/Vector.h"

namespace Tilt {
  struct Calculator {
    struct Trial {
      float start[2];
      float middle[2];
      float end[2];

      float2 getDifference() {
        float2 startVec = float2(start[0], start[1]);
        float2 middleVec = float2(middle[0], middle[1]);
        float2 endVec = float2(end[0], end[1]);

        float2 deltaForward = middleVec - startVec;
        float2 deltaBackward = middleVec - endVec;
        return (deltaForward + deltaBackward) / 2;
      }
    };

    struct Result {
      float2 mean = float2(0);
      float2 M2 = float2(0);
      float count = 0;

      void update(float2 x) {
        count += 1;

        float2 oldMean = mean;
        mean += (x - mean) / count;
        M2 += (x - oldMean) * (x - mean);
      }

      float2 getVariance() const {
        return M2 / count;
      }
    };

    // This is optimized for feedback with 500 μs integrator lag time.
    static constexpr uint32_t settleTime = KilohertzLoopRound(2000);
    static constexpr uint32_t paddingTime = KilohertzLoopRound(50);
    static constexpr float reportPeriodSeconds = 1.0;

    Calculator();
    Calculator(Command command);

    void update();

  private:
    float displacementSize;
    uint32_t movementTime;
    uint32_t trialsPerResult;

    Trial pendingTrial;
    Result pendingResult;
    uint32_t getTimePerTrial();

    void updateForTrial(uint32_t timeInTrial);
  };
};