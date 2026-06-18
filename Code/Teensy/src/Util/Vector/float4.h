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
};
