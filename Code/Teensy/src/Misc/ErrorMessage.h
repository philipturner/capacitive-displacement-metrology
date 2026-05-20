#pragma once

#include <stdint.h>

struct ErrorMessage {
  static inline bool errorExists = false;
  static inline char buffer[512]; // not guaranteed to be null terminated
  static inline uint32_t cursor = 0;

  static void reset();

  static void nullTerminate();

  static void addNewline();

  static void addString(const char* cString);
  
  static void addInteger(int32_t x);

  static void addFloat(float x);
};