import Foundation

struct Emulator {
  enum Mode {
    case normal
    case imaging
  }
  
  var startTime: Double
  var previousTime: Double
  var modeStartTime: Double
  var idCursor: Int = 0
  var mode: Mode = .normal
  
  init() {
    startTime = Date().timeIntervalSince1970
    previousTime = startTime
    modeStartTime = startTime
  }
  
  mutating func setMode(_ newMode: Mode, currentTime: Double) {
    if newMode != mode {
      modeStartTime = currentTime
      mode = newMode
    }
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
    let elapsedTime = currentTime - startTime
    defer {
      previousTime = currentTime
    }
    
    if elapsedTime < 5.0 {
      setMode(.normal, currentTime: currentTime)
    } else if elapsedTime < 15.0 {
      setMode(.imaging, currentTime: currentTime)
    } else {
      setMode(.normal, currentTime: currentTime)
    }
    
    switch mode {
    case .normal:
      return createNormalLines(currentTime: currentTime)
    case .imaging:
      var output: [LineParser.Line] = []
      
      let deltaTime = currentTime - modeStartTime
      if deltaTime == 0 {
        
      }
      
      fatalError("Not implemented.")
    }
    
    /*
    if elapsedTime < Self.imagingStartTime {
      let elapsedMicros = Int(elapsedTime * 1e6)
      let elapsedLogPeriods = elapsedMicros / 72
      
      let output = createNormalLines(until: elapsedLogPeriods)
      lineCursor = elapsedLogPeriods
      return output
    } else if elapsedTime < Self.imagingEndTime {
      if imagingStartLineID == nil {
        imagingStartLineID = lineCursor
      }
      
      let imageElapsedTime = elapsedTime - Self.imagingStartTime
      let elapsedMicros = Int(imageElapsedTime * 1e6)
      let elapsedPixels = elapsedMicros / 144
      
      // TODO: Function to generate simulated lines from STM imaging mode
      // - parameters to set up the UI
      // - ability to simulate i, v, and d modes
      // - mapping time to progress in number of pixels
      // - fake STM image of a square lattice
      
      return []
    } else {
      lineCursor += pixelCursor
      pixelCursor = 0
      imagingStartLineID = nil
      
      
    }
     */
  }
}

extension Emulator {
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
  
  mutating func createNormalLines(currentTime: Double) -> [LineParser.Line] {
    let lineCursorPrevious = Self
      .elapsedMicros(modeStartTime, previousTime) / History.logPeriodMicros
    let lineCursorNext = Self
      .elapsedMicros(modeStartTime, currentTime) / History.logPeriodMicros
    
    var lines: [LineParser.Line] = []
    for relativeLineID in lineCursorPrevious..<lineCursorNext {
      let elapsedTimeMicros = relativeLineID * History.logPeriodMicros
      let sinePeriodMicros = 1000
      let phaseMicros = elapsedTimeMicros % sinePeriodMicros
      
      let phaseNormalized = Float(phaseMicros) / Float(sinePeriodMicros)
      let dacVoltage = 10 * Self.triangleWave(phaseNormalized)
      let current = 200 * Self.squareWave(phaseNormalized)
      
      var line = LineParser.Line()
      line.id = idCursor
      idCursor += 1
      
      line.values[0] = current
      line.values[1] = dacVoltage
      line.values[2] = Float.random(in: -0.001..<0.001)
      line.values[3] = Float.pi
      lines.append(line)
    }
    return lines
  }
}
