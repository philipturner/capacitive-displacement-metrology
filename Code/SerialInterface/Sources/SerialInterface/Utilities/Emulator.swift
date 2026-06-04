import Foundation

struct Emulator {
  enum Mode: UInt8 {
    case dacTest = 1
    case imaging = 5
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
      fatalError("Not implemented.")
    }
    
    return output
    
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

// MARK: - Normal Lines

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
  
  mutating func createHistoryLines(currentTime: Double) -> [LineParser.Line] {
    let lineCursorPrevious = Self
      .elapsedMicros(modeStartTime, previousTime) / History.logPeriodMicros
    let lineCursorNext = Self
      .elapsedMicros(modeStartTime, currentTime) / History.logPeriodMicros
    
    var output: [LineParser.Line] = []
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
      output.append(line)
    }
    return output
  }
}

// MARK: - Imaging Lines

extension Emulator {
  static let imagingMode: Imaging.Mode = .image
  
  static let pixelPeriodMicros: Int = 144
  
  static let imageResolution: Int = 64
  static let imageSize: Float = 1.5
  static let imageCenters: [SIMD2<Float>] = [
    SIMD2<Float>(-3.0, -2.0),
    SIMD2<Float>(2.0, 2.0),
  ]
  
  mutating func createImagingParameterLines() -> [LineParser.Line] {
    var output: [LineParser.Line] = []
    for i in 0..<2 {
      var line = LineParser.Line()
      line.flags = 4
      line.id = idCursor
      idCursor += 1
      
      if i == 0 {
        line.values[0] = Float(Self.imagingMode.rawValue)
        line.values[1] = Float(Self.imageResolution)
        line.values[2] = Self.imageSize
        line.values[3] = Self.imageCenters[0].x
        line.values[4] = Self.imageCenters[0].y
      } else {
        if Self.imagingMode == .dualVideo {
          line.values[0] = Self.imageCenters[1].x
          line.values[1] = Self.imageCenters[1].y
        } else {
          line.values[0] = -100
          line.values[1] = -100
        }
      }
      output.append(line)
    }
    return output
  }
  
  mutating func createImagingLines(currentTime: Double) -> [LineParser.Line] {
    let pixelCursorPrevious = Self
      .elapsedMicros(modeStartTime, previousTime) / History.logPeriodMicros
    let pixelCursorNext = Self
      .elapsedMicros(modeStartTime, currentTime) / History.logPeriodMicros
  }
}
