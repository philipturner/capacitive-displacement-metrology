import SwiftSerial

class Application {
  nonisolated(unsafe)
  static let global = Application()
  
  let serial: SerialPort
  
  private init() {
    self.serial = SerialPort(path: "/dev/cu.usbmodem182280901")
  }
  
  func initialize() async {
    try! await serial.open(
      receiveRate: .baud115200,
      transmitRate: .baud115200)
    
    CommandTransmitter.launchPollingTask()
  }
}
