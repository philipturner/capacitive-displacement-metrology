#include "SimpleScanner.h"

SimpleScanner::SimpleScanner() {

}

// uint32_t channelID;
// uint32_t targetWavePeriod;
// float bipolarAmplitude;
SimpleScanner::SimpleScanner(Command command) {
  if (command.alphaCode == 'x') {
    channelID = 1;
  } else {
    channelID = 2;
  }
}