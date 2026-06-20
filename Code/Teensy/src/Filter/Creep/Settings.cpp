#include "Settings.h"

#include "Diagnostics/Log.h"

using namespace Creep;

void Settings::update(Command command) {
  switch (command.alphaCode) {
    case 'c': {
      creepConstants = float2(command.attributes[0]);
      break;
    }
    case 'x': {
      creepConstants.x = command.attributes[0];
      break;
    }
    case 'y': {
      creepConstants.y = command.attributes[0];
      break;
    }
  }
}

void Settings::forward() {
  Log::write(
    Log::Flags::creepSettings,
    creepConstants.x * 100.0f,
    creepConstants.y * 100.0f);
}