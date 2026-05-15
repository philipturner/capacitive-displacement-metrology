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
      Application.queue.sync {
        let triggers = self.history.triggers
        self.history = History(triggers: triggers)
      }
    }
    
    var lines: [LineParser.Line]
    do {
      lines = try lineParser.decode(bytes: bytes)
    } catch let error as LineParser.StartCodeCorruptionError {
      reset(error: error)
      lines = try! lineParser.decode(bytes: error.uncorruptedBytes)
    } catch {
      fatalError("Unexpected error type.")
    }
    
    do {
      try lineParser.count(lines: lines)
    } catch let error as LineParser.NonContiguousError {
      reset(error: error)
      try! lineParser.count(lines: error.uncorruptedLines)
      lines = error.uncorruptedLines
    } catch {
      fatalError("Unexpected error type.")
    }
    return lines
  }
  
  func startLineExtractionThread() {
    DispatchQueue.global().async { [self] in
      let startTime = Date().timeIntervalSince1970
      var previousLineID: Int = .zero
      
      func createTestLines() -> [LineParser.Line] {
        let currentTime = Date().timeIntervalSince1970
        let elapsedTime = currentTime - startTime
        let elapsedMicros = Int(elapsedTime * 1e6)
        let elapsedLogPeriods = elapsedMicros / 49
        
        var lines: [LineParser.Line] = []
        for i in previousLineID..<elapsedLogPeriods {
          let elapsedTimeMicros = i * 49
          let sinePeriodMicros = 1000
          let phaseMicros = elapsedTimeMicros % sinePeriodMicros
          
          let phaseNormalized = Float(phaseMicros) / Float(sinePeriodMicros)
          let dacVoltage = 10 * Self.triangleWave(phaseNormalized)
          let current = 200 * Self.squareWave(phaseNormalized)
          
          var line = LineParser.Line(id: i, values: .zero)
          line.values[0] = current
          line.values[1] = dacVoltage
          line.values[2] = Float.random(in: -0.001..<0.001)
          line.values[3] = Float.pi
          lines.append(line)
        }
        previousLineID = elapsedLogPeriods
        
        return lines
      }
      
      while true {
        Watchdog.notify(threadID: 1, code: 0)
        usleep(10_000)
        Watchdog.notify(threadID: 1, code: 1)
        
        commandTransmitter.transmitSerialInput(port: port)
        Watchdog.notify(threadID: 1, code: 2)
        
        var lines: [LineParser.Line]
        if Self.serialEmulation {
          lines = createTestLines()
        } else {
          let bytes = LineParser.getValidBytes(port: port)
          lines = createLines(bytes: bytes)
        }
        Watchdog.notify(threadID: 1, code: 5)
        
        Application.queue.sync {
          self.history.addLines(lines)
        }
        Watchdog.notify(threadID: 1, code: 6)
      }
    }
  }
}
