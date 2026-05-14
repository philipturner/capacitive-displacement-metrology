import Foundation
import SwiftSerial

class Application: @unchecked Sendable {
  static let serialEmulation: Bool = true
  static let queue = DispatchQueue(
    label: "avoiding.bugs.from.swift.concurrency")
  
  let ui: UI
  let port: SerialPort
  let commandTransmitter: CommandTransmitter
  var lineParser: LineParser
  var history: History
  
  init() {
    self.ui = UI()
    if Self.serialEmulation {
      self.port = SerialPort(path: "/dev/cu.debug-console")
    } else {
      self.port = SerialPort(path: "/dev/cu.usbmodem182280901")
    }
    self.commandTransmitter = CommandTransmitter()
    self.lineParser = LineParser()
    self.history = History()
    
    try! port.open(
      receiveRate: .baud115200,
      transmitRate: .baud115200)
    commandTransmitter.startPollingThread()
    startLineExtractionThread()
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
  
  func startLineExtractionThread() {
    DispatchQueue.global().async {
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
          let dacVoltage = 10 * Self.triangleWave(phaseNormalized)
          let current = 200 * Self.squareWave(phaseNormalized)
          
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
        
        self.commandTransmitter.transmitSerialInput(
          port: self.port)
        
        var entries: [Entry] = []
        if Self.serialEmulation {
          entries = createTestEntries()
        } else {
          entries = self.lineParser.extractEntries(
            port: self.port)
        }
        
        Application.queue.sync {
          self.history.addEntries(entries)
        }
      }
    }
  }
}
