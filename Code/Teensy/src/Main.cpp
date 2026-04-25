#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Metrology/Metrology.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

float positiveDriveVoltage = 50;

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();
}

void voltageRamp(float startVoltage, float endVoltage) {
  constexpr float duration = 1e-3;

  uint32_t startTime = micros();
  while (true) {
    uint32_t latestTime = micros();
    float elapsedTime = float(latestTime - startTime) / float(1e6);
    float progress = elapsedTime / duration;
    progress = min(progress, 1);
    progress = max(progress, 0);

    float voltage = 0;
    voltage += progress * endVoltage;
    voltage += (1 - progress) * startVoltage;

    PA95::writeVoltage(1, voltage);

    if (elapsedTime > duration) {
      break;
    }
  }
}

void programBody() {
  voltageRamp(0, -positiveDriveVoltage);

  uint32_t stepCount = 3000;
  for (uint32_t i = 0; i < stepCount; ++i) {
    voltageRamp(-positiveDriveVoltage, positiveDriveVoltage);
    PA95::writeVoltage(1, -positiveDriveVoltage);
    delayMicroseconds(1000);
  }
  
  voltageRamp(-positiveDriveVoltage, 0);
}

void loop() {
  delay(500);

  float time = float(millis()) / 1000;
  Serial.print("time: ");
  Serial.print(time, 2);
  Serial.print(" seconds");
  Serial.println();

  if (Serial.available() > 0) {
    char incomingByte = Serial.read();

    if (incomingByte == 's') {
      programBody();
    }
  }
}

