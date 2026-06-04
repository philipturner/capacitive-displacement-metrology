import Foundation

struct SerialEmulator {
  var startTime: Double
  var previousLineID: Int = 0
  
  init() {
    startTime = Date().timeIntervalSince1970
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
  
  mutating func createTestLines() -> [LineParser.Line] {
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
      
      var line = LineParser.Line(id: i, flags: .zero, values: .zero)
      line.values[0] = current
      line.values[1] = dacVoltage
      line.values[2] = Float.random(in: -0.001..<0.001)
      line.values[3] = Float.pi
      lines.append(line)
    }
    previousLineID = elapsedLogPeriods
    
    return lines
  }
}
