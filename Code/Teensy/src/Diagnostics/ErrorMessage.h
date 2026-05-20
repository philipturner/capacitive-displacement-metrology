#pragma once

#include <stdint.h>

struct ErrorMessage {
  enum class Type {
    none = 0,
    fatal = 1,
    recoverable = 2,
  };

  static inline Type errorType = Type::none;
  static inline char buffer[512]; // not guaranteed to be null terminated
  static inline uint32_t cursor = 0;

  static void reset();

  static bool hasError();
  
  static void nullTerminate();

  static void addNewline();

  static void addString(const char* cString);
  
  static void addInteger(int32_t x);

  static void addFloat(float x);
};