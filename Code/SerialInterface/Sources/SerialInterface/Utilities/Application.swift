import Foundation
import SwiftSerial

struct ApplicationDescriptor {
  /// Optional. The triggers for the history.
  var triggers: [Trigger] = []
  
  init() {
    
  }
}

class Application: @unchecked Sendable {
  static let serialEmulation: Bool = false
  static let queue = DispatchQueue(
    label: "avoiding.bugs.from.swift.concurrency")
  
  let ui: UI
  let port: SerialPort
  let commandTransmitter: CommandTransmitter
  var lineParser: LineParser
  var history: History
  
  init(descriptor: ApplicationDescriptor) {
    self.ui = UI()
    if Self.serialEmulation {
      self.port = SerialPort(path: "/dev/cu.debug-console")
    } else {
      self.port = SerialPort(path: "/dev/cu.usbmodem182280901")
    }
    self.commandTransmitter = CommandTransmitter()
    self.lineParser = LineParser()
    self.history = History(triggers: descriptor.triggers)
    
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
  
  private func createLines(bytes: [UInt8]) -> [LineParser.Line] {
    func reset(error: LocalizedError) {
      print("Resetting lineParser and history.")
      if let description = error.errorDescription {
        print("error description:")
        print(description)
      }
      
      lineParser = LineParser()
      
    }
    
    var lines: [LineParser.Line] = []
    var resetHistory = false
    
    do {
      lines = try lineParser.decodeLines(data: bytes)
    } catch let error as LineParser.StartCodeCorruptionError {
      let bytes = error.uncorruptedData
      print(error.description)
      
      lineParser = LineParser()
      resetHistory = true
      entries = try! Entry.decodeEntries(data: bytes)
    } else {
      fatalError("Unexpected error type.")
    }
    
    do {
      try self.lineParser.finishExtraction(entries: entries)
    } catch let error as LineParser.NonContiguousError {
      entries = error.uncorruptedEntries
      print(error.description)
      
      lineParser = LineParser()
      resetHistory = true
      try! lineParser.finishExtraction(
        entries: error.uncorruptedEntries)
    } catch {
      fatalError("Unexpected error type.")
    }
    
    if resetHistory {
      Application.queue.sync {
        if resetHistory {
          let triggers = self.history.triggers
          self.history = History(triggers: triggers)
        }
        self.history.addEntries(entries)
      }
    }
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
        Watchdog.notify(threadID: 1, code: 0)
        usleep(10_000)
        Watchdog.notify(threadID: 1, code: 1)
        
        self.commandTransmitter.transmitSerialInput(
          port: self.port)
        Watchdog.notify(threadID: 1, code: 2)
        
        var lines: [Line] = []
        var resetHistory = false
        if Self.serialEmulation {
          entries = createTestEntries()
        } else {
          do {
            let bytes = lineParser.getValidBytes(port: port)
            entries = try Entry.decodeEntries(data: bytes)
          } catch let error as Entry.StartCodeCorruptionError {
            let bytes = error.uncorruptedData
            print(error.description)
            
            lineParser = LineParser()
            entries = try! Entry.decodeEntries(data: bytes)
          }
        }
        Watchdog.notify(threadID: 1, code: 5)
        
        do {
          try self.lineParser.finishExtraction(entries: entries)
        } catch let error as LineParser.NonContiguousError {
          entries = error.uncorruptedEntries
          print(error.description)
          
          lineParser = LineParser()
          try! lineParser.finishExtraction(
            entries: error.uncorruptedEntries)
        } catch {
          fatalError("Unexpected error type.")
        }
        Watchdog.notify(threadID: 1, code: 6)
        
        Application.queue.sync {
          self.history.addEntries(entries)
        }
        Watchdog.notify(threadID: 1, code: 7)
      }
    }
  }
}
