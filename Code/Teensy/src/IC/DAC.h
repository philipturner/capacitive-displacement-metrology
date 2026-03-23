#pragma once

#include <SPI.h>

inline uint8_t CS_DAC1 = 36;
inline uint8_t CS_DAC2 = 37;

void transferDAC2(uint8_t byte0, uint8_t byte1, uint8_t byte2);