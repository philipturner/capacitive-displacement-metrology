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
    let sinePeriodMicros = 1000
    let phaseMicros = elapsedTimeMicros % sinePeriodMicros
      
    let phaseNormalized = Float(phaseMicros) / Float(sinePeriodMicros)
    let dacVoltage = 10 * Self.triangleWave(phaseNormalized)
    let current = 200 * Self.squareWave(phaseNormalized)
    
    var output: SIMD8<Float> = .zero
    output[0] = current
    output[1] = dacVoltage
    output[2] = Float.random(in: -0.001..<0.001)
    output[3] = Float.pi
    return output
  }
  
  mutating func createHistoryLines(currentTime: Double) -> [LineParser.Line] {
    let lineCursorPrevious = Self
      .elapsedMicros(startTime, previousTime) / History.logPeriodMicros
    let lineCursorNext = Self
      .elapsedMicros(startTime, currentTime) / History.logPeriodMicros
    
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
