#include "IC/ADC.h"
#include "IC/CDC.h"
#include "IC/DAC.h"
#include "IC/PA95.h"
#include "Metrology/Metrology.h"
#include "Time/KilohertzLoop.h"
#include "Time/TimeStatistics.h"
#include "Util/Application.h"
#include "Util/Bitset.h"

uint32_t stepCount = 5000;
float bipolarDriveVoltage = 100;
float positiveDriveVoltage = 0;

void setup() {
  Application::setupSerial();
  Application::setupSPI();
  Application::setupI2C();
}

void voltageRamp(
  float startVoltage, 
  float endVoltage, 
  float duration = 600e-6
) {
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

    PA95::writeVoltage(3, voltage);

    if (elapsedTime > duration) {
      break;
    }
  }
}

void programBody() {
  voltageRamp(0, -positiveDriveVoltage);

  for (uint32_t i = 0; i < stepCount; ++i) {
    voltageRamp(-positiveDriveVoltage, positiveDriveVoltage);

    #if true
    PA95::writeVoltage(3, -positiveDriveVoltage);
    #else
    voltageRamp(positiveDriveVoltage, -positiveDriveVoltage, 22.5e-6);
    #endif

    //delayMicroseconds(25);
  }

  voltageRamp(-positiveDriveVoltage, 0);
}

// Workaround for problem where the Teensy program won't upload.
void processInput(char incomingByte) {
  float _positiveDriveVoltage;
  if (incomingByte == 'u') {
    _positiveDriveVoltage = bipolarDriveVoltage;
  } else if (incomingByte == 'd') {
    _positiveDriveVoltage = -bipolarDriveVoltage;
  } else {
    return;
  }

  positiveDriveVoltage =  _positiveDriveVoltage;
  programBody();
  positiveDriveVoltage = 0;
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
    
    processInput(incomingByte);

    // Prevent accidents from multiple key presses.
    while (Serial.available() > 0) {
      char byte = Serial.read();
      Serial.print("ignored input: ");
      Serial.print(byte);
      Serial.println();
    }
  }
}
