import Foundation
import PythonKit
import SwiftSerial

struct ApplicationDescriptor {
  var pythonLibraryPath: String?
  var trajectoryLagTime: Double?
  var triggers: [Trigger] = []
  var useEmulator: Bool = false
}

class Application: @unchecked Sendable {
  static let queue = DispatchQueue(
    label: "avoiding.bugs.from.swift.concurrency")
  nonisolated(unsafe)
  static var needsToClose: Bool = false
  nonisolated(unsafe)
  static var nextPauseTime: Double?
  
  let useEmulator: Bool
  var lineParser: LineParser
  let port: SerialPort
  let ui: UI
  
  init(descriptor: ApplicationDescriptor) {
    guard let pythonLibraryPath = descriptor.pythonLibraryPath else {
      fatalError("Descriptor was incomplete.")
    }
    PythonLibrary.useLibrary(at: pythonLibraryPath)
    
    self.useEmulator = descriptor.useEmulator
    self.lineParser = LineParser()
    if useEmulator {
      self.port = SerialPort(path: "/dev/cu.debug-console")
    } else {
      self.port = SerialPort(path: "/dev/cu.usbmodem182280901")
    }
    self.ui = UI(descriptor: descriptor)
    
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
          nextLoopTime += 8.333e-3
        }
      } else {
        usleep(1_000)
        continue
      }
      Watchdog.notify(threadID: 0, code: 0)
      
      if let pauseTime = Application.nextPauseTime {
        if pauseTime < currentTime {
          Application.queue.sync {
            if ui.mode == .imaging {
              fatalError("Cannot pause while in imaging mode.")
            }
          }
          continue
        }
      }
      
      loop()
      
      ui.app.processEvents()
    }
  }
}
