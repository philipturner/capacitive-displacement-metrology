#pragma once

#include <stdint.h>

struct ErrorMessage {
  static inline bool errorExists = false;
  static char message[512];
  static inline uint32_t messageCursor = 0;

  static void reset();

  static void addString(const char* cString);
  
  // use snprintf("%i")
  static void addInteger(uint32_t x);

  // snprintf("%.Xf") should work
  // https://forum.pjrc.com/index.php?threads/using-double-precision-numbers-in-serial-teensy-3-2-and-4-0.62234/post-248310
  static void addFloat(float x);
};