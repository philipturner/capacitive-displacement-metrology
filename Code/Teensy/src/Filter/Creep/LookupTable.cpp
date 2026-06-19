#include "LookupTable.h"

#include <math.h>

using namespace Creep;

LookupTable::LookupTable() {

}

LookupTable::LookupTable(bool notDefaultConstructor) {
  for (uint32_t binID = resolution; binID < binCount; ++binID) {
    float dt = float(binID) / float(resolution);

    float sampleCount = float(supersamplingRate) / float(dt);
    float loopSize = ceilf(sampleCount);

    float weight = 0;
    for (float i = 0; i < loopSize; ++i) {
      float denominator = dt * loopSize + i;
      weight += 1.0f / denominator;
    }
    bins[binID] = weight;
  }
}