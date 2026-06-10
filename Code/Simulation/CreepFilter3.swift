import Foundation

let creepConstant: Float = 0.85e-2 / log(10)
let logScaleResolution: Int = 4 // even numbers never have >1 transition/cycle
let timeOriginUpdateRate: Int = 100
typealias PreciseType = Float

let supersamplingRateHighRes: Int = 30
let capacitySimpleLowRes: Int = 1000
let timeLimit: Int = 1000
let enableCreepCancellation: Bool = true

// MARK: - Common Structures

struct Sample {
  var dV: Float = .zero
  var time: Float = .zero
  var queueTime: Float = .zero
  
  init() {
    
  }
  
  init(dV: Float, time: Float) {
    self.dV = dV
    self.time = time
    self.queueTime = time
  }
  
  init(_ source1: Sample, _ source2: Sample) {
    dV = source1.dV + source2.dV
    
    func getWeightedTime() -> Float {
      let denominator = abs(source1.dV) + abs(source2.dV)
      if denominator < 1e-6 {
        return (source1.time + source2.time) / 2
      }
      
      var accumulator: Float = .zero
      accumulator += source1.time * abs(source1.dV)
      accumulator += source2.time * abs(source2.dV)
      accumulator /= abs(source1.dV) + abs(source2.dV)
      return accumulator
    }
    time = getWeightedTime()
    
    queueTime = (source1.queueTime + source2.queueTime) / 2
  }
}

struct SampleBuffer {
  var capacity: Int
  var data: [Sample]
  var startIndex: Int = .zero
  var endIndex: Int = .zero
  
  init(capacity: Int) {
    self.capacity = capacity
    self.data = Array(repeating: Sample(), count: capacity)
  }
  
  var count: Int {
    endIndex - startIndex
  }
  
  mutating func insert(_ sample: Sample) {
    if count >= capacity {
      fatalError("Exceeded capacity of ring buffer.")
    }
    
    data[endIndex % capacity] = sample
    endIndex += 1
  }
  
  mutating func removeFirst() {
    guard startIndex < endIndex else {
      fatalError("Cannot remove first.")
    }
    startIndex += 1
  }
  
  subscript(index: Int) -> Sample {
    _read {
      let slotID = (startIndex + index) % capacity
      yield data[slotID]
    }
  }
  
  @inline(__always)
  func forEach(_ closure: (Sample) -> Void) {
    for i in startIndex..<endIndex {
      let slotID = i % capacity
      closure(data[slotID])
    }
  }
  
  mutating func shiftTimeOrigin() {
    for i in startIndex..<endIndex {
      let slotID = i % capacity
      data[slotID].time -= Float(timeOriginUpdateRate)
      data[slotID].queueTime -= Float(timeOriginUpdateRate)
    }
  }
}

struct Queue {
  var maxTime: Float
  var buffer: SampleBuffer
  
  init(maxTime: Float, capacity: Int) {
    self.maxTime = maxTime
    self.buffer = SampleBuffer(capacity: capacity)
  }
  
  mutating func removeFirst(time: Float) -> Sample? {
    guard buffer.count >= 2 else {
      return nil
    }
    
    let sample0 = buffer[0]
    let sample1 = buffer[1]
    let queueTime = (sample0.queueTime + sample1.queueTime) / 2
    
    // Arbitrary choice for threshold: average time vs. time of samples[1]
    // The former gives a more consistent distribution of samples across the
    // queues.
    let dt = time - queueTime
    if dt > maxTime {
      buffer.removeFirst()
      buffer.removeFirst()
      return Sample(sample0, sample1)
    } else {
      return nil
    }
  }
}

// MARK: - Simple Creep Filter

struct SimpleCreepFilter {
  var currentResponse: PreciseType = .zero
  var currentStimulus: Float = .zero
  var timeOrigin: Int = .zero
  var buffer: SampleBuffer
  var supersamplingRate: Int
  
  init(capacity: Int, supersamplingRate: Int = 1) {
    self.buffer = SampleBuffer(capacity: capacity)
    self.supersamplingRate = supersamplingRate
  }
  
  static func createSupersamplingOffsets(rate: Int) -> [Float] {
    var output: [Float] = []
    for i in 0..<rate {
      let offset = Float(i) / Float(rate)
      output.append(offset)
    }
    return output
  }
  
  func creepRate(time: Int) -> Float {
    let relativeTime = Float(time - timeOrigin)
    let offsets = Self.createSupersamplingOffsets(rate: supersamplingRate)
    let sampleWeight = 1 / Float(supersamplingRate)
    
    var accumulator: PreciseType = .zero
    buffer.forEach { sample in
      let dt = relativeTime - sample.time
      guard dt >= 1 else {
        fatalError("This should never happen.")
      }
      
      for offset in offsets {
        let multiplier = sampleWeight / (dt + offset)
        accumulator += PreciseType(sample.dV * multiplier)
      }
    }
    return creepConstant * Float(accumulator)
  }
  
  mutating func shiftTimeOrigin() {
    timeOrigin += timeOriginUpdateRate
    
    buffer.shiftTimeOrigin()
  }
  
  // Returns the change in response.
  mutating func update(stimulus: Float, time: Int) {
    let creep_dx = creepRate(time: time)
    let dV = stimulus - currentStimulus
    currentResponse += PreciseType(creep_dx + dV)
    currentStimulus = stimulus
    
    let relativeTime = Float(time - timeOrigin)
    let sample = Sample(dV: dV, time: relativeTime)
    if buffer.count >= buffer.capacity {
      buffer.removeFirst()
    }
    buffer.insert(sample)
    
    if relativeTime > Float(timeOriginUpdateRate) {
      shiftTimeOrigin()
    }
  }
}

// MARK: - Efficient Creep Filter

// 98-112 ns execution time so far

struct CreepFilter {
  var currentResponse: PreciseType = .zero
  var currentStimulus: Float = .zero
  var timeOrigin: Int = .zero
  var queues: [Queue] = []
  
  init() {
    for i in (0...33).reversed() {
      let maxTime = logScaleResolution * (1 << i)
      
      func getCapacity() -> Int {
        var multiplier: Int
        if i == 0 {
          multiplier = 2
        } else {
          multiplier = 1
        }
        
        return multiplier * logScaleResolution
      }
      
      let queue = Queue(
        maxTime: Float(maxTime),
        capacity: getCapacity())
      queues.append(queue)
    }
  }
  
  func creepRate(time: Int) -> Float {
    let relativeTime = Float(time - timeOrigin)
    
    var accumulator: PreciseType = .zero
    for queue in queues {
      queue.buffer.forEach { sample in
        // Any way to pre-compute this somewhat for samples farther in the past?
        let dt = relativeTime - sample.time
        accumulator += PreciseType(sample.dV / dt)
      }
    }
    return creepConstant * Float(accumulator)
  }
  
  mutating func shiftTimeOrigin() {
    timeOrigin += timeOriginUpdateRate
    
    for queueID in queues.indices {
      queues[queueID].buffer.shiftTimeOrigin()
    }
  }
  
  mutating func shiftSamples(time: Int) {
    let relativeTime = Float(time - timeOrigin)
    
    var removesDone: Int = 0
    for queueID in queues.indices.reversed() {
      let removed = queues[queueID].removeFirst(time: relativeTime)
      guard let removed else {
        continue
      }
      
      if queueID == 0 {
        print(queues[queueID].maxTime)
        print(removed.dV)
        print(removed.time)
        print(time)
        fatalError("Reached end of delay line.")
      }
      
      queues[queueID - 1].buffer.insert(removed)
      
      // Limit the number of removal operations per cycle. The infrequent
      // events where multiple bins switch will be spread out over the few
      // following cycles.
      removesDone += 1
      if removesDone >= 4 {
        break
      }
    }
    
    if removesDone <= 1 {
      if relativeTime > Float(timeOriginUpdateRate) {
        shiftTimeOrigin()
      }
    }
  }
  
  mutating func update(stimulus: Float, time: Int) {
    let creep_dx = creepRate(time: time)
    let dV = stimulus - currentStimulus
    currentResponse += PreciseType(creep_dx + dV)
    currentStimulus = stimulus
    
    let relativeTime = Float(time - timeOrigin)
    let sample = Sample(dV: dV, time: relativeTime)
    queues[queues.count - 1].buffer.insert(sample)
    
    shiftSamples(time: time)
  }
}

// MARK: - Scripting

var groundTruthFilter = SimpleCreepFilter(
  capacity: timeLimit,
  supersamplingRate: supersamplingRateHighRes)
var simpleFilter = SimpleCreepFilter(
  capacity: capacitySimpleLowRes)
var efficientFilter = CreepFilter()
var creepOffsetSimple: Float = 0
var creepOffsetEfficient: Float = 0

func createStimulusSignal(time: Int) -> Float {
  if time < 10 {
    return 0
  } else {
    return 1
  }
}

let startTimestamp = Date().timeIntervalSince1970
for time in 0..<timeLimit {
  let creepRateSimple = simpleFilter.creepRate(time: time)
  let creepRateEfficient = efficientFilter.creepRate(time: time)
  if enableCreepCancellation {
    creepOffsetSimple -= creepOffsetSimple
    creepOffsetEfficient -= creepOffsetEfficient
  }
  let stimulus = createStimulusSignal(time: time)
  
  func fmtNumber(_ number: Float) -> String {
    var output = String(format: "%.4f", number)
    if number >= 0 {
      output = " " + output
    }
    return output
  }
  
  if true {
    print("t:", time, terminator: " | ")
    print("V:", fmtNumber(stimulus), terminator: " | ")
    print("V:", fmtNumber(stimulus + creepOffsetSimple), terminator: " | ")
    print("V:", fmtNumber(stimulus + creepOffsetEfficient), terminator: " | ")
    print("x:", fmtNumber(groundTruthFilter.currentResponse), terminator: " | ")
    print("x:", fmtNumber(simpleFilter.currentResponse), terminator: " | ")
    print("x:", fmtNumber(efficientFilter.currentResponse), terminator: " | ")
    
    let errorSimple = simpleFilter.currentResponse - groundTruthFilter.currentResponse
    let errorEfficient = efficientFilter.currentResponse - groundTruthFilter.currentResponse
    print("dx:", fmtNumber(errorSimple), terminator: " | ")
    print("dx:", fmtNumber(errorEfficient), terminator: " | ")
    print()
  }
  
  groundTruthFilter.update(stimulus: stimulus, time: time)
  simpleFilter.update(stimulus: stimulus + creepOffsetSimple, time: time)
  efficientFilter.update(stimulus: stimulus + creepOffsetEfficient, time: time)
}
let endTimestamp = Date().timeIntervalSince1970
print("program execution time:", terminator: " ")
print(String(format: "%.6f", endTimestamp - startTimestamp))
