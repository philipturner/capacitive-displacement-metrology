#include "TimeStatistics.h"

void TimeStatistics::integrate(uint32_t jumpDuration) {
  if (jumpDuration > 1000000) {
    this->above1000000us_jumps += 1;
  } else if (jumpDuration > 100000) {
    this->above100000us_jumps += 1;
  } else if (jumpDuration > 10000) {
    this->above10000us_jumps += 1;
  } else if (jumpDuration > 1000) {
    this->above1000us_jumps += 1;
  } else if (jumpDuration > 100) {
    this->above100us_jumps += 1;
  } else if (jumpDuration > 20) {
    this->above20us_jumps += 1;
  } else if (jumpDuration == 20) {
    this->exactly20us_jumps += 1;
  } else if (jumpDuration < 20) {
    this->under20us_jumps += 1;
  }
  this->total_jumps += 1;
}