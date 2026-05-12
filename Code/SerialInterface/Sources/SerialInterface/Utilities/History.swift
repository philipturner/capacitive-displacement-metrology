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
  static let maxAverageCount: Int = {
    History.maxEntryCount / History.pointsPerAverage
  }()
  
  struct TimedSample {
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
  var sampleCursor: Int = .zero
  private var samplesBuffer: [TimedSample]
  private var latestSample: TimedSample?
  
  var averageCursor: Int = .zero
  private var samplesForNextAverage: [TimedSample] = []
  private var averagesBuffer: [TimedAverage]
  private var latestAverage: TimedAverage?
  
  init() {
    let emptySample = TimedSample(
      time: .nan,
      values: SIMD4<Float>(repeating: .nan))
    samplesBuffer = Array(
      repeating: emptySample,
      count: Self.maxEntryCount)
    
    let emptyAverage = TimedAverage(
      time: .nan,
      minimum: SIMD4<Float>(repeating: .nan),
      average: SIMD4<Float>(repeating: .nan),
      maximum: SIMD4<Float>(repeating: .nan))
    averagesBuffer = Array(
      repeating: emptyAverage,
      count: Self.maxAverageCount)
  }
  
  func addEntries(_ input: [Entry]) {
    for entry in input {
      let logPeriodSeconds = Double(1e-6) * Double(Self.logPeriodMicros)
      var time = Double(entry.id) * logPeriodSeconds
      if firstTime == nil {
        firstTime = time
      }
      time -= firstTime!
      
      let sample = TimedSample(time: time, values: entry.values)
      let ringIndex = sampleCursor % Self.maxEntryCount
      samplesBuffer[ringIndex] = sample
      sampleCursor += 1
      latestSample = sample
      
      samplesForNextAverage.append(sample)
      incorporateAveragePoint()
    }
  }
  
  private func incorporateAveragePoint() {
    guard samplesForNextAverage.count >= Self.pointsPerAverage else {
      return
    }
    
    func createAverage() -> TimedAverage {
      var accumulator = TimedAverage(
        time: .zero,
        minimum: SIMD4<Float>(repeating: .greatestFiniteMagnitude),
        average: SIMD4<Float>(repeating: .zero),
        maximum: SIMD4<Float>(repeating: -.greatestFiniteMagnitude))
      
      for entry in samplesForNextAverage {
        accumulator.time += entry.time
        accumulator.minimum.replace(
          with: entry.values,
          where: entry.values .< accumulator.minimum)
        accumulator.average += entry.values
        accumulator.maximum.replace(
          with: entry.values,
          where: entry.values .> accumulator.maximum)
      }
      accumulator.time /= Double(samplesForNextAverage.count)
      accumulator.average /= Float(samplesForNextAverage.count)
      
      return accumulator
    }
    let average = createAverage()
    
    let ringIndex = averageCursor % Self.maxAverageCount
    averagesBuffer[ringIndex] = average
    averageCursor += 1
    latestAverage = average
  }
  
  func sampleHistory(time historyTime: Double) -> [TimedSample] {
    guard historyTime >= 0 else {
      fatalError("Invalid time.")
    }
    guard let latestSample else {
      return []
    }
    let earliestTime = latestSample.time - historyTime
    
    var output: [TimedSample] = []
    let endIndex = max(0, sampleCursor - 1)
    let startIndex = max(0, sampleCursor - Self.maxEntryCount)
    for i in (startIndex...endIndex).reversed() {
      let ringIndex = i % Self.maxEntryCount
      let sample = samplesBuffer[ringIndex]
      
      if sample.time >= earliestTime {
        output.append(sample)
      } else {
        break
      }
    }
    
    output.reverse()
    return output
  }
  
  func averageHistory(time historyTime: Double) -> [TimedAverage] {
    guard historyTime >= 0 else {
      fatalError("Invalid time.")
    }
    guard let latestAverage else {
      return []
    }
    let earliestTime = latestAverage.time - historyTime
    
    var output: [TimedAverage] = []
    let endIndex = max(0, averageCursor - 1)
    let startIndex = max(0, averageCursor - Self.maxAverageCount)
    for i in (startIndex...endIndex).reversed() {
      let ringIndex = i % Self.maxAverageCount
      let average = averagesBuffer[ringIndex]
      
      if average.time >= earliestTime {
        output.append(average)
      } else {
        break
      }
    }
    
    output.reverse()
    return output
  }
}
