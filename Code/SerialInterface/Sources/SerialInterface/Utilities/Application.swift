import Foundation
import SwiftSerial

class Application {
  nonisolated(unsafe)
  static let global = Application()
  static let serialEmulation: Bool = true
  
  let serial: SerialPort
  var lineParser = LineParser()
  let history = History()
  
  // This caused crash with both Matplotlib and PyQtGraph. I have given up on
  // trying to use conventional Swift concurrency with these open. Thankfully,
  // it appears legal to have other 'await' and 'Task' in the same application,
  // as long as it doesn't touch the data accessed by Python.
  //
  // When using a Python-heavy UI, the program freezes in the event loop
  // right when 'app.processEvents()' is called. I narrowed down the cause to
  // where the UI is initialized. It cannot happen until the asynchronous code
  // from `await serial.open` has been await'ed. I tried the solution of
  // wrapping this in a `Task`, but apparently you cannot wait on task
  // completion in top-level code (the compiler always throws errors).
  let serialQueue = DispatchQueue(label: "swiftconcurrencycausesbugswithpython")
  
  private init() {
    if Self.serialEmulation {
      self.serial = SerialPort(path: "/dev/cu.debug-console")
    } else {
      self.serial = SerialPort(path: "/dev/cu.usbmodem182280901")
    }
  }
  
  func initialize() {
    try! serial.open(
      receiveRate: .baud115200,
      transmitRate: .baud115200)
    
    CommandTransmitter.launchPollingTask()
     
    Application.launchLineExtractionTask()
  }
  
  private static func squareWave(_ phaseNormalized: Float) -> Float {
    if phaseNormalized < 0.5 {
      return 1
    } else {
      return -1
    }
  }
  
  private static func triangleWave(_ phaseNormalized: Float) -> Float {
    var progress: Float
    if phaseNormalized < 0.5 {
      progress = 2 * phaseNormalized
    } else {
      progress = 2 * (1 - phaseNormalized)
    }
    return 2 * progress - 1
  }
  
  static func launchLineExtractionTask() {
    Task.detached {
      let startTime = Date().timeIntervalSince1970
      var previousEntryID: Int = .zero
      func createTestEntries() -> [Entry] {
        let currentTime = Date().timeIntervalSince1970
        let elapsedTime = currentTime - startTime
        let elapsedMicros = Int(elapsedTime * 1e6)
        let elapsedLogPeriods = elapsedMicros / 49
        
        var entries: [Entry] = []
        for i in previousEntryID..<elapsedLogPeriods {
          let elapsedTimeMicros = i * 49
          let sinePeriodMicros = 1000
          let phaseMicros = elapsedTimeMicros % sinePeriodMicros
          
          let phaseNormalized = Float(phaseMicros) / Float(sinePeriodMicros)
          let dacVoltage = 10 * triangleWave(phaseNormalized)
          let current = 200 * squareWave(phaseNormalized)
          
          var entry = Entry(id: i, values: .zero)
          entry.values[0] = current
          entry.values[1] = dacVoltage
          entry.values[2] = Float.random(in: -0.001..<0.001)
          entry.values[3] = Float.pi
          entries.append(entry)
        }
        previousEntryID = elapsedLogPeriods
        
        return entries
      }
      
      while true {
        usleep(10_000)
        
        await CommandTransmitter.transmitSerialInput()
        
        var entries: [Entry] = []
        if Self.serialEmulation {
          entries = createTestEntries()
        } else {
          entries = Application.global.lineParser.extractEntries()
        }
        
        Application.global.serialQueue.sync {
          Application.global.history.addEntries(entries)
        }
      }
    }
  }
}
