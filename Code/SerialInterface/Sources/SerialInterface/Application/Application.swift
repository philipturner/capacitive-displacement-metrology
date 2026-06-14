import Foundation
import PythonKit
import SwiftSerial

struct ApplicationDescriptor {
  var pythonLibraryPath: String?
  var trajectoryLagTime: Double?
  var triggers: [Trigger] = []
  var useEmulator: Bool = false
  var useImagingWindow: Bool = false
}

class Application: @unchecked Sendable {
  static let queue = DispatchQueue(
    label: "avoiding.bugs.from.swift.concurrency")
  nonisolated(unsafe)
  static var needsToClose: Bool = false
  nonisolated(unsafe)
  static var nextPauseTime: Double?
  
  var useEmulator: Bool
  var useImagingWindow: Bool
  
  let ui: UI
  let port: SerialPort
  var lineParser: LineParser
  var history: History
  
  init(descriptor: ApplicationDescriptor) {
    guard let pythonLibraryPath = descriptor.pythonLibraryPath else {
      fatalError("Descriptor was incomplete.")
    }
    
    PythonLibrary.useLibrary(at: pythonLibraryPath)
    self.useEmulator = descriptor.useEmulator
    
    self.ui = UI(trajectoryLagTime: descriptor.trajectoryLagTime)
    if useEmulator {
      self.port = SerialPort(path: "/dev/cu.debug-console")
    } else {
      self.port = SerialPort(path: "/dev/cu.usbmodem182280901")
    }
    self.lineParser = LineParser()
    self.history = History(triggers: descriptor.triggers)
    
    try! port.open(
      receiveRate: .baud115200,
      transmitRate: .baud115200)
  }
  
  func run(_ loop: () -> Void) {
    CommandTransmitter.startPollingThread()
    
    Watchdog.initialize(trackedThreads: 2)
    
    startLineExtractionThread()
    
    var nextLoopTime = Date().timeIntervalSince1970
    while !Application.needsToClose {
      let currentTime = Date().timeIntervalSince1970
      if currentTime > nextLoopTime {
        while currentTime > nextLoopTime {
          nextLoopTime += 16.666e-3
        }
      } else {
        usleep(1_000)
        continue
      }
      Watchdog.notify(threadID: 0, code: 0)
      
      if let pauseTime = Application.nextPauseTime {
        if pauseTime < currentTime {
          continue
        }
      }
      
      loop()
      
      ui.app.processEvents()
    }
  }
}
