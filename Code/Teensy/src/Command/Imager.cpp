#include "Imager.h"

#include "Application/Application.h"
#include "Util/Feedback.h"
#include "Util/FilterUtil.h"
#include <Arduino.h>

Imager::Mode Imager::getMode(char code) {
  if (code == 'i') {
    return Imager::Mode::image;
  } else if (code == 'v') {
    return Imager::Mode::video;
  } else if (code == 'd') {
    return Imager::Mode::dualVideo;
  } else {
    Serial.println("This should never happen.");
    exit(0);
  }
}

Imager::Imager() {

}

Imager::Imager(Command command) {
  mode = getMode(command.alphaCode);
}

void Imager::update() {

}