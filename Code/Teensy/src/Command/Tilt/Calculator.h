#pragma once

#include "Command/Parsing/Command.h"

namespace Tilt {
  struct Calculator {
    Calculator();
    Calculator(Command command);

    void update();

  private:
    float displacement;
  };
};