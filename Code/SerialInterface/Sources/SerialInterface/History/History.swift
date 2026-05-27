import Foundation

struct TimeAxis {
  var shortLength: Double = .zero
  var shortMajorTick: Double = .zero
  var longLength: Double = .zero
  var longMajorTick: Double = .zero
}

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
  static let logPeriodMicros: Int = 48
  static let historyLengthSeconds: Int = 30
  static let maxEntryCount: Int = {
    var output = History.historyLengthSeconds
    output *= 1_000_000 / History.logPeriodMicros
    return output
  }()
  
  var timeAxis = TimeAxis()
  var pointsPerAverage: Int
  var maxAverageCount: Int {
    History.maxEntryCount / pointsPerAverage
  }
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
  
  var sampleCursor: Int = .zero
  private(set) var samplesBuffer: [TimedSample] = []
  private(set) var latestSample: TimedSample?
  
  var averageCursor: Int = .zero
  private var samplesForNextAverage: [TimedSample] = []
  private(set) var averagesBuffer: [TimedAverage] = []
  private(set) var latestAverage: TimedAverage?
  
  private(set) var triggers: [Trigger]
  var triggerEvents: [TriggerEvent] = []
  var currentSpike: TriggerEvent?
  
  init(descriptor: HistoryDescriptor) {
    guard let shortTimeLength = descriptor.shortTimeLength,
          let longTimeLength = descriptor.longTimeLength else {
      fatalError("Descriptor was incomplete.")
    }
    self.triggers = descriptor.triggers
    
    timeAxis.shortLength = shortTimeLength
    timeAxis.shortMajorTick =
    descriptor.shortTimeMajorTick ?? shortTimeLength / 5
    
    timeAxis.longLength = longTimeLength
    timeAxis.longMajorTick =
    descriptor.longTimeMajorTick ?? longTimeLength / 5
    
    let microsecondsPerAverage = (longTimeLength / 500) * 1e6
    pointsPerAverage = max(2, Int(microsecondsPerAverage) / Self.logPeriodMicros)
    
    reset()
  }
  
  mutating func reset() {
    let emptySample = TimedSample(
      time: .nan,
      values: SIMD8<Float>(repeating: .nan))
    sampleCursor = .zero
    samplesBuffer = Array(
      repeating: emptySample,
      count: Self.maxEntryCount)
    latestSample = nil
    
    let emptyAverage = TimedAverage(
      time: .nan,
      minimum: SIMD8<Float>(repeating: .nan),
      average: SIMD8<Float>(repeating: .nan),
      maximum: SIMD8<Float>(repeating: .nan))
    averageCursor = .zero
    samplesForNextAverage = []
    averagesBuffer = Array(
      repeating: emptyAverage,
      count: self.maxAverageCount)
    latestAverage = nil
    
    triggerEvents = []
    currentSpike = nil
  }
  
  mutating func addLines(_ input: [LineParser.Line]) {
    guard triggerEvents.count <= Self.triggerEventCacheSize else {
      fatalError("This should never happen.")
    }
    
    for line in input {
      if line.flags == 0 {
        
      } else if line.flags == 1 {
        reset()
        if line.values[0] == 4 {
          Application.historyCurrentSpikeOverride = true
        } else {
          Application.historyCurrentSpikeOverride = false
        }
        continue
      } else {
        fatalError("Flags not handled: \(line.flags)")
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
      checkCurrentSpike(sample: sample)
      
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
  
  private mutating func checkCurrentSpike(sample: TimedSample) {
    guard Application.historyCurrentSpikeOverride else {
      return
    }
    guard Application.nextPauseTime == nil else {
      return
    }
    guard currentSpike == nil else {
      return
    }
    
    if abs(sample.values[1]) > 1e-9,
       abs(sample.values[2]) < 100e-12 {
      var trigger = Trigger()
      trigger.type = .level(1e-9)
      trigger.polarity = .signAgnostic
      trigger.channel = 0
      
      let triggerEvent = TriggerEvent(
        cursor: sampleCursor,
        centerTime: sample.time,
        trigger: trigger)
      
      currentSpike = triggerEvent
      
      let currentTime = Date().timeIntervalSince1970
      Application.nextPauseTime = currentTime + 1
    }
  }
}
