import Foundation

struct Emulator {
  static let imagingStartTime: Double = 5.0 // units: seconds
  
  var startTime: Double
  var lineCursor: Int = 0
  var imagingStartLineID: Int?
  
  init() {
    startTime = Date().timeIntervalSince1970
  }
  
  mutating func createTestLines() -> [LineParser.Line] {
    let currentTime = Date().timeIntervalSince1970
    let elapsedTime = currentTime - startTime
    
    if elapsedTime < Self.imagingStartTime {
      let elapsedMicros = Int(elapsedTime * 1e6)
      let elapsedLogPeriods = elapsedMicros / 49
      
      let output = createNormalLines(until: elapsedLogPeriods)
      lineCursor = elapsedLogPeriods
      return output
    } else {
      if imagingStartLineID == nil {
        imagingStartLineID = lineCursor
      }
      
      // TODO: Function to generate simulated lines from STM imaging mode
      // - parameters to set up the UI
      // - ability to simulate i, v, and d modes
      // - mapping time to progress in number of pixels
      // - fake STM image of a square lattice
      
      return []
    }
  }
}

// MARK: - Normal Serial

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
  
  
  func createNormalLines(until elapsedLogPeriods: Int) -> [LineParser.Line] {
    var lines: [LineParser.Line] = []
    for i in lineCursor..<elapsedLogPeriods {
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
    return lines
  }
}

// MARK: - Imaging
