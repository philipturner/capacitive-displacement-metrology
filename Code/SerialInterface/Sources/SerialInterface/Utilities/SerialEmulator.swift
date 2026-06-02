import Foundation

struct SerialEmulation {
  var startTime: Double
  var previousLineID: Int = 0
  
  init() {
    startTime = Date().timeIntervalSince1970
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
