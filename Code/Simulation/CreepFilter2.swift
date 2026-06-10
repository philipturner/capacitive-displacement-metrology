import Foundation

let creepConstant: Float = 0.85e-2 / log(10)
let logScaleResolution: Int = 4 // even numbers never have >1 transition/cycle
let timeOriginUpdateRate: Int = 100
typealias PreciseType = Float

// t: 10000 | V: 1.0000 | x: 1.0340 | x: 1.0187 | x: 1.0361 | dx: 0.0000 | dx: 0.0000 |  0.002110 |  0.000161 |

// ground truth: 1.03400
//
// logScaleResolution = 4
// 1,  false: 1.03611 | 0.000000121
// 2,  false: 1.03498 | 0.000000134
// 3,  false: 1.03463 | 0.000000144
// 4,  false: 1.03446 | 0.000000157
// 5,  false: 1.03436 | 0.000000174
// 7,  false: 1.03425 | 0.000000209
// 10, false: 1.03417 | 0.000000282
// 14, false: 1.03411 | 0.000000373
// 20, false: 1.03407 | 0.000000513
// 25, false: 1.03406 | 0.000000624
// 30, false: 1.03404 | 0.000000744
//
// 1,  true:  1.03611 | 0.000000114
// 2,  true:  1.03550 | 0.000000118
// 3,  true:  1.03513 | 0.000000123
// 5,  true:  1.03479 | 0.000000142
// 10, true:  1.03449 | 0.000000151
// 20, true:  1.03429 | 0.000000182
// 30, true:  1.03421 | 0.000000218
// 50, true:  1.03413 | 0.000000292
// 80, true:  1.03409 | 0.000000371
// 130, true: 1.03405 | 0.000000586
//
// Changing logScaleResolution does not change the outcome at all, even for the
// largest supersampling rates. Changing from 4 to 2 reduces the time by 33%.

let supersamplingRateSimple: Int = 10
let supersamplingRateEfficient: Int = 1
let supersamplingCutoff: Bool = false
let capacitySimple: Int = 100
let timeLimitSimple: Int = 100
let timeLimitEfficient: Int = 10000

let displayResults: Bool = true

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
  
  init(capacity: Int, supersamplingRate: Int) {
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
  var supersamplingRate: Int
  
  init(supersamplingRate: Int) {
    self.supersamplingRate = supersamplingRate
    
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
        let dt = relativeTime - sample.time
        
        if supersamplingCutoff {
          var sampleCount = Float(supersamplingRate) / dt
          if sampleCount <= 1 {
            accumulator += PreciseType(sample.dV / dt)
          } else {
            sampleCount.round(.up)
            
            var localAccumulator: Float = 0
            var i: Float = 0
            while i < sampleCount {
              let offset = i / sampleCount
              localAccumulator += 1 / (dt + offset)
              i += 1
            }
            
            accumulator += sample.dV * localAccumulator / sampleCount
          }
        } else {
          let sampleWeight = 1 / Float(supersamplingRate)
          for i in 0..<supersamplingRate {
            let offset = Float(i) / Float(supersamplingRate)
            let multiplier = sampleWeight / (dt + offset)
            accumulator += PreciseType(sample.dV * multiplier)
          }
        }
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

// MARK: - Testing

#if true

var simpleCreepFilter = SimpleCreepFilter(
  capacity: capacitySimple,
  supersamplingRate: supersamplingRateSimple)
var creepFilter = CreepFilter(
  supersamplingRate: supersamplingRateEfficient)
let stepVoltageAmplitude: Float = 1
let stepVoltageTime: Int = 10
var errorSimple: Float = .zero
var errorEfficient: Float = .zero

var timeCheckpoint1 = Date().timeIntervalSince1970
var timeCheckpoint2: Double = 0
var timeCheckpoint3: Double = 0

for time in 0..<timeLimitEfficient {
  var voltage: Float
  var position: Float
  var creepRate: Float
  if time < stepVoltageTime {
    voltage = .zero
    position = .zero
    creepRate = .zero
  } else if time == stepVoltageTime {
    voltage = stepVoltageAmplitude
    position = .zero
    creepRate = .zero
  } else {
    let dt = Float(time - stepVoltageTime)
    voltage = stepVoltageAmplitude
    position = stepVoltageAmplitude * (1 + creepConstant * log(dt))
    creepRate = stepVoltageAmplitude * (creepConstant / dt)
  }
  
  func pad(_ string: String, length: Int) -> String {
    var output = string
    while output.count < length {
      output = " " + output
    }
    return output
  }
  func display(_ number: Float) -> String {
    let output = String(format: "%.5f", number)
    return output
  }
  
  if time == timeLimitSimple {
    timeCheckpoint2 = Date().timeIntervalSince1970
  }

  if displayResults {
    print("t:", pad("\(time)", length: 4), terminator: " | ")
    print("V:", display(voltage), terminator: " | ")
    print("x:", display(position), terminator: " | ")
    print("x:", display(Float(simpleCreepFilter.currentResponse)), terminator: " | ")
    print("x:", display(Float(creepFilter.currentResponse)), terminator: " | ")
    print("dx:", display(creepRate), terminator: " | ")
    if time < timeLimitSimple {
      let simulatedCreepRate = simpleCreepFilter.creepRate(time: time)
      print("dx:", display(simulatedCreepRate), terminator: " | ")
    }
    do {
      let simulatedCreepRate2 = creepFilter.creepRate(time: time)
      print("dx:", display(simulatedCreepRate2), terminator: " | ")
    }
    
    func getFormattedError(_ error: Float) -> String {
      var output = String(format: "%.6f", error)
      
      let length = String("-X.XXXXXX").count
      output = pad(output, length: length)
      return output
    }
    
    if time < timeLimitSimple {
      errorSimple = Float(simpleCreepFilter.currentResponse) - position
    }
    errorEfficient = Float(creepFilter.currentResponse) - position - errorSimple
    errorEfficient /= Float(position - voltage)
    print(getFormattedError(errorSimple), terminator: " | ")
    print(getFormattedError(errorEfficient), terminator: " | ")
    print()
  }
  
  if time < timeLimitSimple {
    simpleCreepFilter.update(stimulus: voltage, time: time)
  }
  creepFilter.update(stimulus: voltage, time: time)
}

timeCheckpoint3 = Date().timeIntervalSince1970

func getFormattedTime(_ x: Double, _ int: Int) -> String {
  var output: String = ""
  output += String(format: "%.6f", x)
  output += " "
  output += String(format: "%.9f", x / Double(int))
  return output
}
print(getFormattedTime(
  timeCheckpoint2 - timeCheckpoint1,
  timeLimitSimple))
print(getFormattedTime(
  timeCheckpoint3 - timeCheckpoint2,
  timeLimitEfficient - timeLimitSimple))

var accumulator: Int = 0
for queue in creepFilter.queues {
  print(queue.maxTime, queue.buffer.count)
  accumulator += queue.buffer.count
}
print(accumulator)

#else

let voltageSequence: [Float] = [
  0, 0, 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 20, 20,
//  0, 0, 0, 0, 1,
]

var creepFilter = CreepFilter()

for time in 0..<1000 {
  var voltage: Float
  if time < voltageSequence.count {
    voltage = voltageSequence[time]
  } else {
    voltage = voltageSequence.last!
  }
  
  print()
  print("time:", time)
  print("voltage:", voltage)
  
  creepFilter.update(stimulus: voltage, time: time)
  
  print("creep filter:")
  for queueID in creepFilter.queues.indices {
    print("- queues[\(queueID)]:")
    
    let queue = creepFilter.queues[queueID]
    print("  - maxTime: \(queue.maxTime)")
    
    var sampleID: Int = 0
    queue.buffer.forEach { sample in
      print("  - samples[\(sampleID)]:", terminator: " ")
      print(sample.dV, terminator: ", ")
      print(sample.time, terminator: " ")
      print(sample.queueTime, terminator: " ")
      
      let dt1 = Float(time - creepFilter.timeOrigin) - sample.time
      let dt2 = Float(time - creepFilter.timeOrigin) - sample.queueTime
      print("(\(-dt1), \(-dt2))")
      
      sampleID += 1
    }
  }
  
  func getSum() -> Float {
    var output: Float = .zero
    for queue in creepFilter.queues {
      queue.buffer.forEach { sample in
        output += sample.dV
      }
    }
    return output
  }
  print("sum:", getSum())
}

#endif
