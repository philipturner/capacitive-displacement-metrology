#include "TestProgram.h"

#include "Filter.h"
#include <Arduino.h>

using namespace Creep;

uint32_t timeLimit = 10000;
bool displayResults = false;

void displayExecutionTime(uint32_t deltaMicros, uint32_t iters) {
  float deltaTime = float(deltaMicros) * 1e-6;
  Serial.print(deltaTime, 6);
  Serial.print(" ");

  float timePerIter = deltaTime / float(iters);
  Serial.print(timePerIter, 9);
  Serial.println();
}

void displayQuantity(const char *label, float value) {
  Serial.print(label);
  Serial.print(": ");
  Serial.print(value, 6);
  Serial.print(" | ");
}

void Creep::runTestProgram() {
  Settings::creepConstants = float2(0.0085);

  auto filter = Filter(true);
  uint32_t stepVoltageTime = 10;

  uint32_t checkpoint1 = micros();
  for (uint32_t time = 0; time < timeLimit; ++time) {
    float2 voltage;
    float2 position;
    float2 creepRate;
    if (time < stepVoltageTime) {
      voltage = float2(0);
      position = float2(0);
      creepRate = float2(0);
    } else if (time == stepVoltageTime) {
      voltage = float2(1);
      position = float2(0);
      creepRate = float2(0);
    } else {
      float dt = float(time - stepVoltageTime);
      float creepConstant = Settings::creepConstants.x / M_LN10;
      voltage = float2(1);
      position = float2(1 + creepConstant * log(dt));
      creepRate = float2(creepConstant / dt);
    }

    #if true

    if (displayResults) {
      Serial.print("t: ");
      Serial.print(time);
      Serial.print(" | ");

      displayQuantity("V", voltage.x);

      auto simulatedPosition = voltage + filter.futureAccumulatedDrift;
      displayQuantity("x", position.x);
      displayQuantity("x", simulatedPosition.x);

      auto simulatedCreepRate = filter.currentCreepRate;
      displayQuantity("dx", creepRate.x);
      displayQuantity("dx", simulatedCreepRate.x);
      Serial.println();
    }

    filter.update(voltage);

    #else

    Serial.println();
    Serial.print("time: ");
    Serial.println(time);
    Serial.print("voltage: ");
    Serial.println(voltage.x);

    filter.update(voltage);

    Serial.println("creep filter:");
    for (uint32_t queueID = 0; queueID < Settings::queueCount; ++queueID) {
      if (queueID < 25) {
        continue;
      }
      Serial.print("- queues[");
      Serial.print(queueID);
      Serial.print("]:");
      Serial.println();

      auto queue = filter.queues[queueID];
      Serial.print("  - maxTime: ");
      Serial.print(queue.maxTime);
      Serial.println();

      uint32_t startIndex = queue.startIndex;
      uint32_t endIndex = queue.endIndex;
      for (uint32_t sampleID = startIndex; sampleID < endIndex; ++sampleID) {
        auto sample = queue[sampleID];

        Serial.print("- samples[");
        Serial.print(sampleID - startIndex);
        Serial.print("]: ");
        Serial.print(sample.dV.x);
        Serial.print(", ");
        Serial.print(sample.time);
        Serial.print(", ");
        Serial.print(sample.queueTime);
        Serial.println();
      }
    }

    #endif
  }
  uint32_t checkpoint2 = micros();

  displayExecutionTime(checkpoint2 - checkpoint1, timeLimit);
}