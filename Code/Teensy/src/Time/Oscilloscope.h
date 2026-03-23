#pragma once

#include <stdint.h>

#define OSCILLOSCOPE_HISTORY_SIZE 100

struct Oscilloscope {
  float ringBuffer[OSCILLOSCOPE_HISTORY_SIZE];
  float copiedSamples[OSCILLOSCOPE_HISTORY_SIZE];
  uint32_t copiedTimestamp;
  uint32_t staticDisplayTimeNext;

  void initialize();
  void fastLoop();
  void slowLoop();

  void copyData();
  bool shouldDisplayData();
  
  static inline Oscilloscope* _global;
  static void startFastLoop(Oscilloscope *global);
};
