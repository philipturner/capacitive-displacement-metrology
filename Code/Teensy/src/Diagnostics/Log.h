#pragma once

#include "Command/Command.h"

struct Log {
  static constexpr uint32_t logPeriod = 48;
  static constexpr uint32_t logSize = 6000;
  static constexpr uint32_t messageLength = 27;
  static inline float ringBuffers[5][logSize];
  static inline bool isSpecial[logSize];

  static inline uint32_t transmittedMessageID = 0;
  static inline uint32_t unsafeBufferedMessageID = 0;
  static inline uint32_t normalMessageCursor = 0;
  static inline uint32_t specialMessageCursor = uint32_t(1) << 31;

  static void initialize();

  static void transmitBufferedSamples();

  static void throwError(
    const char *cString, 
    int32_t number1,
    int32_t number2,
    int32_t number3);
  
  static void recordMessage(Command::Mode mode);

  static void recordModeChange();
};