import Foundation
import SwiftSerial

class Application {
  nonisolated(unsafe)
  static let global = Application()
  
  let serial: SerialPort
  var lineParser = LineParser()
  let history = History()
  let ui: UI
  
  // This caused crash with both Matplotlib and PyQtGraph. I have given up on
  // trying to use conventional Swift concurrency with these open. Thankfully,
  // it appears legal to have other 'await' and 'Task' in the same application,
  // as long as it doesn't touch the data accessed by Python.
  let serialQueue = DispatchQueue(label: "swiftconcurrencycausesbugswithpython")
  
  private init() {
    // self.serial = SerialPort(path: "/dev/cu.usbmodem182280901")
    self.serial = SerialPort(path: "/dev/cu.debug-console")
    self.ui = UI()
  }
  
  func initialize() async {
    try! await serial.open(
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
        
        // let entries = await Application.global.lineParser.extractEntries()
        let entries = createTestEntries()
        Application.global.serialQueue.sync {
          Application.global.history.addEntries(entries)
        }
      }
    }
  }
}
