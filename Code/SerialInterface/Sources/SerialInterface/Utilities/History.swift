import Foundation

actor History {
  static let logPeriodMicros: Int = 49
  static let historyLengthSeconds: Int = 10
  static let maxEntryCount: Int = {
    var output = History.historyLengthSeconds
    output *= 1_000_000 / History.logPeriodMicros
    return output
  }()
  
  struct TimedPoint {
    // Time is in seconds.
    var time: Double
    var values: SIMD4<Float>
  }
  
  var firstTime: Double?
  var entryCursor: Int = .zero
  private(set) var ringBuffer: [TimedPoint]
  
  init() {
    let emptyPoint = TimedPoint(
      time: .nan,
      values: SIMD4<Float>(repeating: .nan))
    ringBuffer = Array(
      repeating: emptyPoint,
      count: Self.maxEntryCount)
  }
  
  func addEntries(_ input: [Entry]) {
    for entry in input {
      let logPeriodSeconds = Double(1e-6) * Double(Self.logPeriodMicros)
      var time = Double(entry.id) * logPeriodSeconds
      if firstTime == nil {
        firstTime = time
      }
      time -= firstTime!
      
      let point = TimedPoint(time: time, values: entry.values)
      let ringIndex = entryCursor % Self.maxEntryCount
      ringBuffer[ringIndex] = point
      entryCursor += 1
    }
  }
  
  // TODO: Function to extract the latest n points
  
  // TODO: Function to extract every n points, working backward from the
  // latest point
}
