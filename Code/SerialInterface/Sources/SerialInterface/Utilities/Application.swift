import Foundation
import SwiftSerial

class Application {
  nonisolated(unsafe)
  static let global = Application()
  
  // let serial: SerialPort
  // var lineParser = LineParser()
  let history = History()
  
  private init() {
    // self.serial = SerialPort(path: "/dev/cu.usbmodem182280901")
  }
  
  func initialize() async {
    /*
    try! await serial.open(
      receiveRate: .baud115200,
      transmitRate: .baud115200)
    
    CommandTransmitter.launchPollingTask()
     */
    
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
      
      while true {
        usleep(10_000)
        
        /*
         await CommandTransmitter.transmitSerialInput()
        
         let entries = await Application.global.lineParser.extractEntries()
         await Application.global.history.addEntries(entries)
         */
        
        // Test and profile the UI code with fake entries.
        
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
          entry.values[2] = 0
          entry.values[3] = 0
          entries.append(entry)
        }
        previousEntryID = elapsedLogPeriods
        
        await Application.global.history.addEntries(entries)
      }
    }
  }
}
