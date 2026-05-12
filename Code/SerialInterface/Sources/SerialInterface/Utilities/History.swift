import Foundation

actor History {
  static let logPeriodMicros: Int = 49
  static let historyLengthSeconds: Int = 30
  static let maxEntryCount: Int = {
    var output = History.historyLengthSeconds
    output *= 1_000_000 / History.logPeriodMicros
    return output
  }()
  
  static let pointsPerAverage: Int = 100
  
  struct TimedPoint {
    // Time is in seconds.
    var time: Double
    var values: SIMD4<Float>
  }
  
  struct TimedAverage {
    // Time is in seconds.
    var time: Double
    var minimum: SIMD4<Float>
    var average: SIMD4<Float>
    var maximum: SIMD4<Float>
  }
  
  var firstTime: Double?
  var entryCursor: Int = .zero
  private(set) var samplesBuffer: [TimedPoint]
  
  var averageCursor: Int = .zero
  private(set) var averagesBuffer: [TimedAverage]
  private(set) var samplesForNextAverage: [TimedPoint] = []
  
  init() {
    let emptyPoint = TimedPoint(
      time: .nan,
      values: SIMD4<Float>(repeating: .nan))
    samplesBuffer = Array(
      repeating: emptyPoint,
      count: Self.maxEntryCount)
    
    let emptyAverage = TimedAverage(
      time: .nan,
      minimum: SIMD4<Float>(repeating: .nan),
      average: SIMD4<Float>(repeating: .nan),
      maximum: SIMD4<Float>(repeating: .nan))
    averagesBuffer = Array(
      repeating: emptyAverage,
      count: Self.maxEntryCount / Self.pointsPerAverage)
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
      samplesBuffer[ringIndex] = point
      entryCursor += 1
      
      samplesForNextAverage.append(point)
      incorporateAveragePoint()
    }
  }
  
  private func incorporateAveragePoint() {
    guard samplesForNextAverage.count >= Self.pointsPerAverage else {
      return
    }
    
    
  }
  
  // TODO: Function to extract the latest n points
  
  // TODO: Function to extract every n points, working backward from the
  // latest point
  // - min, avg, max
}
