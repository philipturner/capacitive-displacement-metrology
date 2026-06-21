#pragma once

struct Offline {
  static constexpr bool isOffline = false;
  static constexpr bool isOnline = !isOffline;
};