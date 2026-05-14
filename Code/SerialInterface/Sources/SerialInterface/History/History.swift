import Foundation

class History {
  static let logPeriodMicros: Int = 48
  static let historyLengthSeconds: Int = 30
  static let maxEntryCount: Int = {
    var output = History.historyLengthSeconds
    output *= 1_000_000 / History.logPeriodMicros
    return output
  }()
  
  static let pointsPerAverage: Int = 5000 / logPeriodMicros
  static let maxAverageCount: Int = {
    History.maxEntryCount / History.pointsPerAverage
  }()
  static let triggerEventCacheSize: Int = 100
  
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
  private(set) var samplesBuffer: [TimedSample]
  private(set) var latestSample: TimedSample?
  
  var averageCursor: Int = .zero
  private var samplesForNextAverage: [TimedSample] = []
  private(set) var averagesBuffer: [TimedAverage]
  private(set) var latestAverage: TimedAverage?
  
  var trigger: Trigger
  var triggerEvents: [(cursor: Int, centerTime: Double)] = []
  
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
    
    trigger = Trigger()
  }
  
  func addEntries(_ input: [Entry]) {
    guard triggerEvents.count <= Self.triggerEventCacheSize else {
      fatalError("This should never happen.")
    }
    
    for entry in input {
      let logPeriodSeconds = Double(1e-6) * Double(Self.logPeriodMicros)
      var time = Double(entry.id) * logPeriodSeconds
      if firstTime == nil {
        firstTime = time
      }
      time -= firstTime!
      
      let sample = TimedSample(time: time, values: entry.values)
      if let latestSample {
        let centerTime = trigger.check(
          before: latestSample, after: sample)
        if let centerTime {
          let event = (cursor: sampleCursor, centerTime: centerTime)
          triggerEvents.append(event)
        }
      }
      
      let ringIndex = sampleCursor % Self.maxEntryCount
      samplesBuffer[ringIndex] = sample
      sampleCursor += 1
      latestSample = sample
      
      samplesForNextAverage.append(sample)
      incorporateAveragePoint()
    }
    
    if triggerEvents.count > Self.triggerEventCacheSize {
      let elementsToRemove = triggerEvents.count - Self.triggerEventCacheSize
      triggerEvents.removeFirst(elementsToRemove)
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
    
    samplesForNextAverage.removeAll()
  }
}
