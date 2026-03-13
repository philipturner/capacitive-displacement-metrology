#pragma once

#define USE_OSCILLOSCOPE 1

struct RingBuffer {
  float samples[50000];
};

#if USE_OSCILLOSCOPE
// Allocate 200 KB of RAM (a large chunk)
inline RingBuffer ringBuffer;
#endif

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
// Add TBD to the body of kilohertzLoop
void oscilloscopeDisplayLoop();
