#pragma once

#include <stdint.h>

// CRC algorithm used by DAC8140x series.

namespace CRC {
  // bytes: 3 bytes
  uint8_t calculate(const uint8_t bytes[], uint8_t seed = 0);

  // MOSI must be off for the first call to a chip during a program run.
  // MISO_FLAG should be off for the first and second calls.
  // MISO_VALIDITY should be on when the output data is to be used.
  //
  // ## Context
  //
  // Input CRC is always enforced by the device. With incorrect CRC settings
  // or incorrect MOSI checksums, the DAC output doesn't work. MISO checksums
  // are only correct when the current data transfer frame is fetching data
  // after a read operation.
  //
  // When MISO stops working from incorrect SPI speeds, CRC error is flagged
  // and may persist through the next program run. Even when the next program
  // run is correct.
  enum class Flags: uint8_t {
    MOSI          = 0b001,
    MISO_FLAG     = 0b010,
    MISO_VALIDITY = 0b100,
  };

  inline Flags operator| (Flags lhs, Flags rhs) {
    return static_cast<Flags>(
      static_cast<uint8_t>(lhs) |
      static_cast<uint8_t>(rhs));
  };

  inline Flags operator& (Flags lhs, Flags rhs) {
    return static_cast<Flags>(
      static_cast<uint8_t>(lhs) &
      static_cast<uint8_t>(rhs));
  };

  bool isValidConfig(Flags flags);
};