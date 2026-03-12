#pragma once

void timeFidelityDiagnosticLoop();

// Responsiveness test
//
// Keyboard events:
// 'c' received - ADC performs a measurement
// 'd' received - ADC reports contents of ADS8689_RANGE_SEL_REG
// '0' received - ADC writes 0b0000 to ADS8689_RANGE_SEL_REG
// '1' received - ADC writes 0b0001 to ADS8689_RANGE_SEL_REG
//
// During normal program operation, the responsiveness test does
// not execute. The range select register is set to 0 before the kilohertz
// loop starts.
//
// WARNING: Disable the IntervalTimer when in this mode. Otherwise, the
// range select register will report spurious values.
void adcResponsivenessDiagnosticLoop();

// 'a' received - min/avg/max over 1 ms intervals, showing 1 s of history
// 'l' received - take a snapshot of 20 ms of the raw data stream
// 'z' received - zoomed in shapshot of 2 ms
// '0' received - turn off any plotting
//
// There is a problem where the Serial Plotter sometimes displays 1500
// or 2000 samples, instead of 1000. To work around this, press the 'l'
// or 'z' key multiple times until the waveform looks correct.
//
// Fixing the X-axis limits to the Arduino IDE's serial plotter:
// https://www.open-electronics.org/how-to-adjust-x-and-y-axis-scale-in-arduino-serial-plotter-no-extra-software-needed/
// Successfully changed it from 50 to 1000 data points
void oscilloscopeDiagnosticLoop();