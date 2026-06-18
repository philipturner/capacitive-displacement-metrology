#pragma once

struct Offline {
  static constexpr bool isOffline = true;
  static constexpr bool isOnline = !isOffline;
};