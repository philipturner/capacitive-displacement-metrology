import Foundation
import SwiftSerial

class Application {
  nonisolated(unsafe)
  static let global = Application()
  
  let serial: SerialPort
  var lineParser = LineParser()
  let history = History()
  
  private init() {
    self.serial = SerialPort(path: "/dev/cu.usbmodem182280901")
  }
  
  func initialize() async {
    try! await serial.open(
      receiveRate: .baud115200,
      transmitRate: .baud115200)
    
    CommandTransmitter.launchPollingTask()
    
    Application.launchLineExtractionTask()
  }
  
  static func launchLineExtractionTask() {
    Task.detached {
      while true {
        usleep(10_000)
        await CommandTransmitter.transmitSerialInput()
        
        let entries = await Application.global.lineParser.extractEntries()
        await Application.global.history.addEntries(entries)
      }
    }
  }
}
