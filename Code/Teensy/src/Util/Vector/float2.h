#pragma once

struct float2 {
  float x;
  float y;

  float2() {
    x = 0;
    y = 0;
  }

  float2(float a) {
    x = a;
    y = a;
  }

  float2(float x, float y) {
    this->x = x;
    this->y = y;
  }

  float2& operator+=(float2 rhs) {
    this->x += rhs.x;
    this->y += rhs.y;
    return *this;
  }

  float2& operator*=(float2 rhs) {
    this->x *= rhs.x;
    this->y *= rhs.y;
    return *this;
  }
};

inline float2 operator+(float2 lhs, float2 rhs) {
  float2 output = lhs;
  output += rhs;
  return output;
}

inline float2 operator+(float2 lhs, float rhs) {
  return lhs + float2(rhs);
}

inline float2 operator+(float lhs, float2 rhs) {
  return float2(lhs) + rhs;
}

inline float2 operator*(float2 lhs, float2 rhs) {
  float2 output = lhs;
  output *= rhs;
  return output;
}

inline float2 operator*(float2 lhs, float rhs) {
  return lhs * float2(rhs);
}

inline float2 operator*(float lhs, float2 rhs) {
  return float2(lhs) * rhs;
}