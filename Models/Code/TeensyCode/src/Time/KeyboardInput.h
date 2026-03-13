#pragma once

#include "RingBuffer.h"

// TODO: Migrate this to ADC library.
//
// 'c' received - ADC performs a measurement
// 'd' received - ADC reports contents of ADS8689_RANGE_SEL_REG
// '0' received - ADC writes 0b0000 to ADS8689_RANGE_SEL_REG
// '1' received - ADC writes 0b0001 to ADS8689_RANGE_SEL_REG
void adcResponsivenessDiagnosticLoop();

#define USE_RING_BUFFER 1

#if USE_RING_BUFFER
struct RingBuffer {
  float samples[50000];
};

inline RingBuffer ringBuffer;

// 'a' received - min/avg/max over 1 ms intervals, showing 1 s of history
// 'l' received - take a snapshot of 20 ms of the raw data stream
// 'z' received - zoomed in shapshot of 2 ms
// '0' received - turn off any plotting
//
// ## Before using this function:
//
// Ensure SPI is set up for the ADC
// ADC::writeRangeSelect(0b0000);
// ADC::nop(); // prepare for the first sample
// Set up kilohertzLoop with 20 μs period
void oscilloscopeLoop();
#endif