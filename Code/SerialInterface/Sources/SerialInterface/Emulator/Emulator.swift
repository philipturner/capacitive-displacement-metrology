import Foundation

struct Emulator {
  var startTime: Double
  var previousTime: Double
  var idCursor: Int = 0
  
  init() {
    startTime = Date().timeIntervalSince1970
    previousTime = startTime
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
    defer { previousTime = currentTime }
    
    return createHistoryLines(currentTime: currentTime)
  }
}
