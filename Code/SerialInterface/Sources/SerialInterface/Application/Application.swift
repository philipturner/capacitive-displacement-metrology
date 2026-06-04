import Foundation
import SwiftSerial

struct ApplicationDescriptor {
  var historyDescriptor: HistoryDescriptor?
}

class Application: @unchecked Sendable {
  static let serialEmulation: Bool = true
  static let queue = DispatchQueue(
    label: "avoiding.bugs.from.swift.concurrency")
  nonisolated(unsafe)
  static var needsToClose: Bool = false
  nonisolated(unsafe)
  static var nextPauseTime: Double?
  
  let ui: UI
  let port: SerialPort
  var lineParser: LineParser
  var history: History
  
  init(descriptor: ApplicationDescriptor) {
    guard let historyDescriptor = descriptor.historyDescriptor else {
      fatalError("Descriptor was incomplete.")
    }
    
    self.ui = UI()
    if Self.serialEmulation {
      self.port = SerialPort(path: "/dev/cu.debug-console")
    } else {
      self.port = SerialPort(path: "/dev/cu.usbmodem182280901")
    }
    self.lineParser = LineParser()
    self.history = History(descriptor: historyDescriptor)
    
    try! port.open(
      receiveRate: .baud115200,
      transmitRate: .baud115200)
    CommandTransmitter.startPollingThread()
    startLineExtractionThread()
  }
}
