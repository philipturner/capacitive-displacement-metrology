import Foundation

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
      
      output[0] = current
      output[1] = position.x
      output[2] = position.y
      output[3] = z
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
