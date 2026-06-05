import Foundation

struct Emulator {
  enum Mode: UInt8 {
    case dacTest = 1
    case imaging = 8
  }
  
  var startTime: Double
  var previousTime: Double
  var modeStartTime: Double
  var idCursor: Int = 0
  var mode: Mode = .dacTest
  
  init() {
    startTime = Date().timeIntervalSince1970
    previousTime = startTime
    modeStartTime = startTime
  }
  
  static func elapsedMicros(
    _ startTime: Double,
    _ endTime: Double
  ) -> Int {
    let deltaTime = endTime - startTime
    return Int(deltaTime * 1e6)
  }
  
  mutating func update() -> [LineParser.Line] {
    let currentTime = Date().timeIntervalSince1970
    defer {
      previousTime = currentTime
    }
    
    let modeDidUpdate = updateMode(currentTime: currentTime)
    
    var output: [LineParser.Line] = []
    if modeDidUpdate {
      if mode == .imaging {
        output += createImagingParameterLines()
      }
      output.append(createModeChangeLine())
    }
    
    switch mode {
    case .dacTest:
      output += createHistoryLines(currentTime: currentTime)
    case .imaging:
      output += createHistoryLines(currentTime: currentTime)
      output += createImagingLines(currentTime: currentTime)
    }
    
    return output
  }
  
  mutating func updateMode(currentTime: Double) -> Bool {
    let elapsedTime = currentTime - startTime
    
    var newMode: Mode
    if elapsedTime < 5.0 {
      newMode = .dacTest
    } else if elapsedTime < 15.0 {
      newMode = .imaging
    } else {
      newMode = .dacTest
    }
    if newMode != mode {
      previousTime = currentTime
      modeStartTime = currentTime
      mode = newMode
      return true
    } else {
      return false
    }
  }
  
  mutating func createModeChangeLine() -> LineParser.Line {
    var line = LineParser.Line()
    line.flags = 1
    line.id = idCursor
    idCursor += 1
    
    line.values[0] = Float(mode.rawValue)
    return line
  }
}
