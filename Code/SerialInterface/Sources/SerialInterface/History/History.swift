struct History {
  static let logPeriodMicros: Int = 64
  static let historyLengthSeconds: Int = 30
  static let triggerEventCacheSize: Int = 100
  
  static let maxEntryCount: Int = {
    var output = History.historyLengthSeconds
    output *= 1_000_000 / History.logPeriodMicros
    return output
  }()
  
  static let pointsPerAverage: Int = {
    let longTimeLength = TimeAxis.longLength
    guard longTimeLength > 0 else {
      fatalError("Time axis was not set.")
    }
    
    let targetPointCount: Int = 500
    let timePerAverage = longTimeLength / Double(targetPointCount)
    let microsPerAverage = Int(1e6 * timePerAverage)
    
    var output = microsPerAverage / Self.logPeriodMicros
    output = max(output, 2)
    return output
  }()
  
  static var maxAverageCount: Int {
    Self.maxEntryCount / Self.pointsPerAverage
  }
  
  struct TimedSample {
    // Time is in seconds.
    var time: Double
    var values: SIMD8<Float>
  }
  
  struct TimedAverage {
    // Time is in seconds.
    var time: Double
    var minimum: SIMD8<Float>
    var average: SIMD8<Float>
    var maximum: SIMD8<Float>
  }
  
  struct TriggerEvent {
    var cursor: Int
    var centerTime: Double
    var trigger: Trigger
  }
  
  var sampleCursor: Int = 0
  var samplesBuffer: [TimedSample]
  var latestSample: TimedSample?
  
  var averageCursor: Int = 0
  var samplesForNextAverage: [TimedSample] = []
  var averagesBuffer: [TimedAverage]
  var latestAverage: TimedAverage?
  
  var triggers: [Trigger]
  var triggerEvents: [TriggerEvent] = []
  
  init(triggers: [Trigger]) {
    self.triggers = triggers
    self.samplesBuffer = Self.emptySamplesBuffer()
    self.averagesBuffer = Self.emptyAveragesBuffer()
  }
  
  init(copying other: History) {
    self.triggers = other.triggers
    self.samplesBuffer = Self.emptySamplesBuffer()
    self.averagesBuffer = Self.emptyAveragesBuffer()
  }
  
  static func emptySamplesBuffer() -> [TimedSample] {
    let emptySample = TimedSample(
      time: .nan,
      values: SIMD8<Float>(repeating: .nan))
    return Array(
      repeating: emptySample,
      count: Self.maxEntryCount)
  }
  
  static func emptyAveragesBuffer() -> [TimedAverage] {
    let emptyAverage = TimedAverage(
      time: .nan,
      minimum: SIMD8<Float>(repeating: .nan),
      average: SIMD8<Float>(repeating: .nan),
      maximum: SIMD8<Float>(repeating: .nan))
    return Array(
      repeating: emptyAverage,
      count: Self.maxAverageCount)
  }
  
  mutating func addLines(_ input: [LineParser.Line]) {
    guard triggerEvents.count <= Self.triggerEventCacheSize else {
      fatalError("This should never happen.")
    }
    
    for line in input {
      guard line.flags == 0 else {
        fatalError("This should never happen.")
      }
      
      let logPeriodSeconds = Double(1e-6) * Double(Self.logPeriodMicros)
      let time = Double(sampleCursor) * logPeriodSeconds
      
      let sample = TimedSample(time: time, values: line.values)
      if let latestSample {
        for trigger in triggers {
          let centerTime = trigger.check(
            before: latestSample, after: sample)
          if let centerTime {
            let event = TriggerEvent(
              cursor: sampleCursor,
              centerTime: centerTime,
              trigger: trigger)
            triggerEvents.append(event)
          }
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
  
  private mutating func incorporateAveragePoint() {
    guard samplesForNextAverage.count >= Self.pointsPerAverage else {
      return
    }
    
    func createAverage() -> TimedAverage {
      var accumulator = TimedAverage(
        time: .zero,
        minimum: SIMD8<Float>(repeating: .greatestFiniteMagnitude),
        average: SIMD8<Float>(repeating: .zero),
        maximum: SIMD8<Float>(repeating: -.greatestFiniteMagnitude))
      
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
