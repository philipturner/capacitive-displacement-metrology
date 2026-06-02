struct HistoryDescriptor {
  /// Required.
  var shortTimeLength: Double?
  
  /// Optional. Defaults to 1/5 of the short time length.
  var shortTimeMajorTick: Double?
  
  /// Required. The long-time length so the UI can properly configure the
  /// amount of points per average.
  var longTimeLength: Double?
  
  /// Optional. Defaults to 1/5 of the long time length.
  var longTimeMajorTick: Double?
  
  /// Optional. The triggers for the history.
  var triggers: [Trigger] = []
  
  init() {
    
  }
}

struct History {
  static let logPeriodMicros: Int = 72
  static let historyLengthSeconds: Int = 30
  static let maxEntryCount: Int = {
    var output = History.historyLengthSeconds
    output *= 1_000_000 / History.logPeriodMicros
    return output
  }()
  static let triggerEventCacheSize: Int = 100
  
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
  
  var timeAxis: TimeAxis
  var pointsPerAverage: Int
  var maxAverageCount: Int {
    History.maxEntryCount / pointsPerAverage
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
  
  init(descriptor: HistoryDescriptor) {
    guard let longTimeLength = descriptor.longTimeLength else {
      fatalError("Descriptor was incomplete.")
    }
    self.triggers = descriptor.triggers
    self.timeAxis = TimeAxis(descriptor: descriptor)
 
    let microsecondsPerAverage = (longTimeLength / 500) * 1e6
    self.pointsPerAverage = max(
      2, Int(microsecondsPerAverage) / Self.logPeriodMicros)
    
    self.samplesBuffer = Self.emptySamplesBuffer()
    self.averagesBuffer = Self.emptyAveragesBuffer(
      maxCount: History.maxEntryCount / pointsPerAverage)
  }
  
  init(copying other: History) {
    self.triggers = other.triggers
    self.timeAxis = other.timeAxis
    self.pointsPerAverage = other.pointsPerAverage
    
    self.samplesBuffer = Self.emptySamplesBuffer()
    self.averagesBuffer = Self.emptyAveragesBuffer(
      maxCount: History.maxEntryCount / pointsPerAverage)
  }
  
  static func emptySamplesBuffer() -> [TimedSample] {
    let emptySample = TimedSample(
      time: .nan,
      values: SIMD8<Float>(repeating: .nan))
    return Array(
      repeating: emptySample,
      count: Self.maxEntryCount)
  }
  
  static func emptyAveragesBuffer(maxCount: Int) -> [TimedAverage] {
    let emptyAverage = TimedAverage(
      time: .nan,
      minimum: SIMD8<Float>(repeating: .nan),
      average: SIMD8<Float>(repeating: .nan),
      maximum: SIMD8<Float>(repeating: .nan))
    return Array(
      repeating: emptyAverage,
      count: maxCount)
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
    guard samplesForNextAverage.count >= pointsPerAverage else {
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
    
    let ringIndex = averageCursor % self.maxAverageCount
    averagesBuffer[ringIndex] = average
    averageCursor += 1
    latestAverage = average
    
    samplesForNextAverage.removeAll()
  }
}
