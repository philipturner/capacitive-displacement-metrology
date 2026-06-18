#pragma once

struct float4 {
  float x;
  float y;
  float z;
  float w;

  float4() {
    x = 0;
    y = 0;
    z = 0;
    w = 0;
  }

  float4(float a) {
    x = a;
    y = a;
    z = a;
    w = a;
  }

  float4(float x, float y) {
    this->x = x;
    this->y = y;
    this->z = z;
    this->w = w;
  }

  float4& operator+=(float4 rhs) {
    this->x += rhs.x;
    this->y += rhs.y;
    this->z += rhs.z;
    this->w += rhs.w;
    return *this;
  }

  float4& operator*=(float4 rhs) {
    this->x *= rhs.x;
    this->y *= rhs.y;
    this->z *= rhs.z;
    this->w *= rhs.w;
    return *this;
  }
};

inline float4 operator+(float4 lhs, float4 rhs) {
  float4 output = lhs;
  output += rhs;
  return output;
}

inline float4 operator+(float4 lhs, float rhs) {
  return lhs + float4(rhs);
}

inline float4 operator+(float lhs, float4 rhs) {
  return float4(lhs) + rhs;
}

inline float4 operator*(float4 lhs, float4 rhs) {
  float4 output = lhs;
  output *= rhs;
  return output;
}

inline float4 operator*(float4 lhs, float rhs) {
  return lhs * float4(rhs);
}

inline float4 operator*(float lhs, float4 rhs) {
  return float4(lhs) * rhs;
}