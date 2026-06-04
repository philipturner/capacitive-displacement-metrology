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

// MARK: - History Lines

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
  
  private func createHistoryEntry(elapsedTimeMicros: Int) -> SIMD8<Float> {
    var output: SIMD8<Float> = .zero
    switch mode {
    case .dacTest:
      let sinePeriodMicros = 1000
      let phaseMicros = elapsedTimeMicros % sinePeriodMicros
      
      let phaseNormalized = Float(phaseMicros) / Float(sinePeriodMicros)
      let dacVoltage = 10 * Self.triangleWave(phaseNormalized)
      let current = 200 * Self.squareWave(phaseNormalized)
      
      output[0] = current
      output[1] = dacVoltage
      output[2] = Float.random(in: -0.001..<0.001)
      output[3] = Float.pi
      
    case .imaging:
      let timePerRow = Self.imageResolution * Self.pixelPeriodMicros
      let timePerImage = Self.imageResolution * timePerRow
      var time = elapsedTimeMicros
      
      let imageID = time / timePerImage
      if Self.imagingMode == .image, imageID > 0 {
        time = timePerImage - 1
      } else {
        time = time % timePerImage
      }
      var positionY = Float(time) / Float(timePerImage)
      positionY *= Self.imageSize
      positionY -= Self.imageSize / 2
      
      let rowID = time / timePerRow
      time = time % (2 * timePerRow)
      let waveXProgress = Float(time) / Float(2 * timePerRow)
      
      var positionX = cos(2 * Float.pi * waveXProgress)
      positionX = -positionX
      positionX *= Self.imageSize / 2
      positionX *= 2 / Float(3).squareRoot()
      
      var position = SIMD2(positionX, positionY)
      position += Self.getImageCenter(imageID: imageID)
      
      let z = position.x / 10 + position.y / 10
      let current = Self.getCurrent(position: position)
      let positionError = 50e-12 * Float.random(in: -1...1)
      
      output[0] = current
      output[1] = position.x
      output[2] = position.y
      output[3] = z
      output[4] = positionError
    }
    return output
  }
  
  mutating func createHistoryLines(currentTime: Double) -> [LineParser.Line] {
    let lineCursorPrevious = Self
      .elapsedMicros(modeStartTime, previousTime) / History.logPeriodMicros
    let lineCursorNext = Self
      .elapsedMicros(modeStartTime, currentTime) / History.logPeriodMicros
    
    var output: [LineParser.Line] = []
    for lineID in lineCursorPrevious..<lineCursorNext {
      var line = LineParser.Line()
      line.flags = 0
      line.id = idCursor
      idCursor += 1
      
      let elapsedTimeMicros = lineID * History.logPeriodMicros
      line.values = createHistoryEntry(elapsedTimeMicros: elapsedTimeMicros)
      output.append(line)
    }
    return output
  }
}

// MARK: - Imaging Lines

extension Emulator {
  static let pixelPeriodMicros: Int = 144
  static let atomSpacing: Float = 0.246 // units: nm
  
  static let imagingMode: ImagingMode = .image
  static let imageResolution: Int = 64
  static let imageSize: Float = 1.5
  static let imageCenters: [SIMD2<Float>] = [
    SIMD2<Float>(-30, -20),
    SIMD2<Float>(22, 22),
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
  
  private static func getImageCenter(imageID: Int) -> SIMD2<Float> {
    if Self.imagingMode == .dualVideo, imageID % 2 == 1 {
      return Self.imageCenters[1]
    } else {
      return Self.imageCenters[0]
    }
  }
  
  private static func getCurrent(position: SIMD2<Float>) -> Float {
    let x = position[0] / Self.atomSpacing
    let y = position[1] / Self.atomSpacing
    
    var phases: SIMD3<Float> = .zero
    phases[0] = x
    phases[1] = -0.5 * x + (Float(3).squareRoot() / 2) * y
    phases[2] = -0.5 * x - (Float(3).squareRoot() / 2) * y
    
    var corrugationAmplitude: Float = .zero
    for laneID in 0..<3 {
      var phaseNormalized = phases[laneID]
      phaseNormalized -= phaseNormalized.rounded(.down)
      corrugationAmplitude += cos(2 * Float.pi * phaseNormalized)
    }
    corrugationAmplitude /= 3
    
    func randomGaussian() -> Float {
      var u1: Float = .zero
      while u1 < 0.001 {
        u1 = Float.random(in: 0..<1)
      }
      let u2 = Float.random(in: 0..<1)
      
      // Box-Muller Transform formula
      return sqrt(-2.0 * log(u1)) * cos(2.0 * Float.pi * u2)
    }
    
    var output: Float = 1e-9
    output += 0.2e-9 * corrugationAmplitude
    output += 0.05e-9 * randomGaussian()
    return output
  }
  
  private func createPixel(
    imageID: Int,
    rowID: Int,
    columnID: Int
  ) -> SIMD8<Float> {
    var position = SIMD2(Float(columnID), Float(rowID))
    position = (position + 0.5) * Self.imageSize / Float(Self.imageResolution)
    position -= Self.imageSize / 2
    position += Self.getImageCenter(imageID: imageID)
    
    let pixelID = rowID * Self.imageResolution + columnID
    let z = position.x / 10 + position.y / 10
    let current = Self.getCurrent(position: position)
    
    var output: SIMD8<Float> = .zero
    output[0] = Float(pixelID)
    output[1] = position.x
    output[2] = position.y
    output[3] = z
    output[4] = current
    return output
  }
  
  mutating func createImagingLines(currentTime: Double) -> [LineParser.Line] {
    let pixelCursorPrevious = Self
      .elapsedMicros(modeStartTime, previousTime) / Self.pixelPeriodMicros
    let pixelCursorNext = Self
      .elapsedMicros(modeStartTime, currentTime) / Self.pixelPeriodMicros
    
    var output: [LineParser.Line] = []
    for var time in pixelCursorPrevious..<pixelCursorNext {
      let imageID = time / (Self.imageResolution * Self.imageResolution)
      if Self.imagingMode == .image, imageID > 0 {
        break
      }
      time = time % (Self.imageResolution * Self.imageResolution)
      
      let rowID = time / Self.imageResolution
      time = time % Self.imageResolution
      
      var columnID = time
      if rowID % 2 == 1 {
        columnID = (Self.imageResolution - 1) - columnID
      }
      
      if (rowID * Self.imageResolution + columnID) < 0 {
        fatalError("""
          This should never happen.
          \(pixelCursorPrevious)
          \(pixelCursorNext)
          \(time)
          \(imageID)
          \(rowID)
          \(columnID)
          """)
      }
      
      let values = createPixel(
        imageID: imageID,
        rowID: rowID,
        columnID: columnID)
      
      var line = LineParser.Line()
      line.flags = 5
      line.id = idCursor
      idCursor += 1
      
      line.values = values
      output.append(line)
    }
    return output
  }
}
