#pragma once

#include "Command/Parsing/Command.h"
#include "Time/KilohertzLoop.h"
#include "Util/Vector/Vector.h"
#include <math.h>

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

      float2 getStddev() const {
        float2 variance = M2 / count;

        float2 stddev;
        stddev.x = sqrt(variance.x);
        stddev.y = sqrt(variance.y);
        return stddev;
      }
    };

    // This is optimized for feedback with 500 μs integrator lag time.
    static constexpr uint32_t settleTime = KilohertzLoopRound(2000);
    static constexpr uint32_t paddingTime = KilohertzLoopRound(50);
    static constexpr uint32_t stopTime = 5000000;
    static constexpr float reportPeriodSeconds = 1.0;

    Calculator();
    Calculator(Command command);

    void update();

    static void getOriginScannerVoltage(Command command);

  private:
    float displacementSize;
    uint32_t movementTime;
    float2 originScannerVoltage;
    uint32_t trialsPerResult;
    bool isFinished = false;

    Trial pendingTrial = Trial();
    Result pendingResult = Result();
    uint32_t getTimePerTrial();

    void updateForTrial(uint32_t timeInTrial);
  };
};