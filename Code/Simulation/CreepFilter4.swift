import Foundation

let timeLimit: Int = 10000
let displayResults: Bool = true

// MARK: - Data Type Switching

#if false

typealias VectorType = SIMD2<Float>

func vectorInit(repeating value: Float) -> VectorType {
  return SIMD2(repeating: value)
}

func vectorFirst(_ value: VectorType) -> Float {
  return value[0]
}

func vectorMagnitude(_ value: VectorType) -> Float {
  let dV_squared = value * value
  let accumulator = dV_squared[0] + dV_squared[1]
  return accumulator
}

#else

typealias VectorType = Float

func vectorInit(repeating value: Float) -> VectorType {
  return value
}

func vectorFirst(_ value: VectorType) -> Float {
  return value
}

func vectorMagnitude(_ value: VectorType) -> Float {
  return abs(value)
}

#endif

// MARK: - Other Code

struct CreepFilter {
  static let logScaleResolution: Int = 4
  static let queueCount: Int = 33
  static let supersamplingRate: Float = 10
  static let timeOriginUpdateRate: Int = 1
  
  static var creepConstants = vectorInit(repeating: 0.85e-2) // per decade
  
  var creepRateUpdated: Bool = false
  var currentCreepRate = vectorInit(repeating: -1000)
  var accumulatedDrift: VectorType = .zero
  var currentStimulus: VectorType = .zero
  var timeOrigin: Int = .zero
  
  var queues: [Queue] = []
  
  init() {
    for queueID in 0..<Self.queueCount {
      let shiftAmount = (Self.queueCount - 1) - queueID
      let maxTime = Self.logScaleResolution * (1 << shiftAmount)
      
      let queue = Queue(maxTime: Float(maxTime))
      queues.append(queue)
    }
  }
  
  func getRelativeTime(_ time: Int) -> Float {
    return Float(time - timeOrigin)
  }
  
  mutating func updateCreepRate(time: Int) {
    let relativeTime = getRelativeTime(time)
    
    var accumulator: VectorType = .zero
    for queueID in queues.indices {
      let startIndex = queues[queueID].startIndex
      let endIndex = queues[queueID].endIndex
      for sampleID in startIndex..<endIndex {
        // This memory access can be merged with shifting the time origin of
        // all samples. 'relativeTime' will always evaluate to zero. During the
        // very first iteration, where t = 0, there are no samples.
        //
        // First, check correctness of the existing implementation. Record all
        // simulation results to 8 decimal places. Implement the change, and
        // check that the results do not change.
        let sample = queues[queueID][sampleID]
        
        let dt = relativeTime - sample.time
        let sampleCount = Float(Self.supersamplingRate) / dt
        
        if sampleCount <= 1 {
          accumulator += sample.dV / dt
        } else {
          let loopSize = ceil(sampleCount)
          var localAccumulator: Float = .zero
          
          // C++ for (float i = 0; i < sampleCount; ++i)
          var i: Float = 0
          while i < loopSize {
            let offset = i / loopSize
            localAccumulator += 1 / (dt + offset)
            i += 1
          }
          localAccumulator /= loopSize
          
          accumulator += sample.dV * localAccumulator
        }
      }
    }
    accumulator *= Self.creepConstants / log(10) // C++ M_LN10
    
    currentCreepRate = accumulator
    creepRateUpdated = true
  }
  
  mutating func shiftDelayLine(time: Int) {
    let relativeTime = getRelativeTime(time)
    
    var removesDone: Int = 0
    let maxQueueID = Self.queueCount - 1
    for queueID in (0...maxQueueID).reversed() {
      let ready = queues[queueID].hasReadySample(time: relativeTime)
      guard ready else {
        continue
      }
      
      let removed = queues[queueID].removeReady(time: relativeTime)
      
      if queueID > 0 {
        queues[queueID - 1].insert(removed)
      }
      
      removesDone += 1
    }
    
    if Self.logScaleResolution % 2 == 0 {
      if removesDone > 1 {
        fatalError("More than one remove happened.")
      }
    }
  }
  
  mutating func shiftTimeOrigin(time: Int) {
    let relativeTime = getRelativeTime(time)
    guard relativeTime > Float(Self.timeOriginUpdateRate) else {
      return
    }
    
    timeOrigin += Self.timeOriginUpdateRate
    
    for queueID in queues.indices {
      queues[queueID].shiftTimeOrigin()
    }
  }
  
  mutating func update(stimulus: VectorType, time: Int) {
    guard creepRateUpdated else {
      fatalError("Creep rate was not updated.")
    }
    accumulatedDrift += currentCreepRate
    creepRateUpdated = false
    currentCreepRate = vectorInit(repeating: -1000)
    
    let dV = stimulus - currentStimulus
    currentStimulus = stimulus
    
    var sample = Sample()
    sample.dV = dV
    sample.time = getRelativeTime(time)
    sample.queueTime = getRelativeTime(time)
    
    let queueID = Self.queueCount - 1
    queues[queueID].insert(sample)
    
    shiftDelayLine(time: time)
    shiftTimeOrigin(time: time)
  }
}

extension CreepFilter {
  struct Sample {
    var dV: VectorType = .zero
    var time: Float = .zero
    var queueTime: Float = .zero
    
    init() {
      
    }
    
    init(_ source1: Sample, _ source2: Sample) {
      dV = source1.dV + source2.dV
      time = Self.getWeightedTime(source1, source2)
      queueTime = (source1.queueTime + source2.queueTime) / 2
    }
    
    static func getMagnitude(_ sample: Sample) -> Float {
      return vectorMagnitude(sample.dV)
    }
    
    static func getWeightedTime(
      _ source1: Sample,
      _ source2: Sample
    ) -> Float {
      let magnitude1 = getMagnitude(source1)
      let magnitude2 = getMagnitude(source2)
      if magnitude1 + magnitude2 < 1e-6 {
        return (source1.time + source2.time) / 2
      }
      
      var accumulator: Float = .zero
      accumulator += source1.time * magnitude1
      accumulator += source2.time * magnitude2
      accumulator /= magnitude1 + magnitude2
      return accumulator
    }
  }
}

extension CreepFilter {
  struct Queue {
    static let capacity = CreepFilter.logScaleResolution + 2
    
    var maxTime: Float
    var data: [Sample]
    var startIndex: Int = .zero
    var endIndex: Int = .zero
    
    init(maxTime: Float) {
      self.maxTime = maxTime
      
      let emptySample = Sample()
      self.data = Array(
        repeating: emptySample,
        count: Self.capacity)
    }
    
    // C++
    // T& operator[](size_t index)
    // const T& operator[](size_t index) const
    // both: return m_data[index]
    subscript(index: Int) -> Sample {
      _read {
        let slotID = index % Self.capacity
        yield data[slotID]
      }
      _modify {
        let slotID = index % Self.capacity
        yield &data[slotID]
      }
    }
    
    mutating func insert(_ sample: Sample) {
      if endIndex - startIndex >= Self.capacity {
        fatalError("Exceeded capacity of ring buffer.")
      }
      
      self[endIndex] = sample
      endIndex += 1
    }
    
    func hasReadySample(time: Float) -> Bool {
      guard endIndex - startIndex >= 2 else {
        return false
      }
      
      let queueTime0 = self[startIndex + 0].queueTime
      let queueTime1 = self[startIndex + 1].queueTime
      let queueTimeCombined = (queueTime0 + queueTime1) / 2
      
      let dt = time - queueTimeCombined
      if dt > maxTime {
        return true
      } else {
        return false
      }
    }
    
    mutating func removeReady(time: Float) -> Sample {
      let sample0 = self[startIndex + 0]
      let sample1 = self[startIndex + 1]
      startIndex += 2
      
      return Sample(sample0, sample1)
    }
    
    mutating func shiftTimeOrigin() {
      for i in startIndex..<endIndex {
        let slotID = i % Self.capacity
        data[slotID].time -= Float(CreepFilter.timeOriginUpdateRate)
        data[slotID].queueTime -= Float(CreepFilter.timeOriginUpdateRate)
      }
    }
  }
}

#if true

var creepFilter = CreepFilter()
let stepVoltageTime: Int = 10

let checkpoint1 = Date().timeIntervalSince1970

for time in 0..<timeLimit {
  var voltage: VectorType = .zero
  var position: VectorType = .zero
  var creepRate: VectorType = .zero
  if time < stepVoltageTime {
    voltage = .zero
    position = .zero
    creepRate = .zero
  } else if time == stepVoltageTime {
    voltage = vectorInit(repeating: 1)
    position = .zero
    creepRate = .zero
  } else {
    let dt = Float(time - stepVoltageTime)
    let creepConstant = CreepFilter.creepConstants / log(10)
    voltage = vectorInit(repeating: 1)
    position = vectorInit(repeating: 1) * (1 + creepConstant * log(dt))
    creepRate = vectorInit(repeating: 1) * (creepConstant / dt)
  }
  
  func pad(_ string: String, length: Int) -> String {
    var output = string
    while output.count < length {
      output = " " + output
    }
    return output
  }
  func display(_ number: VectorType) -> String {
    let output = String(format: "%.5f", vectorFirst(number))
    return output
  }
  
  creepFilter.updateCreepRate(time: time)
  
  if displayResults {
    print("t:", pad("\(time)", length: 4), terminator: " | ")
    print("V:", display(voltage), terminator: " | ")
    
    let simulatedPosition = voltage + creepFilter.accumulatedDrift
    print("x:", display(position), terminator: " | ")
    print("x:", display(simulatedPosition), terminator: " | ")
    
    let simulatedCreepRate = creepFilter.currentCreepRate
    print("dx:", display(creepRate), terminator: " | ")
    print("dx:", display(simulatedCreepRate), terminator: " | ")
    print()
  }
  
  creepFilter.update(stimulus: voltage, time: time)
}

let checkpoint2 = Date().timeIntervalSince1970

func getFormattedTime(_ x: Double, _ int: Int) -> String {
  var output: String = ""
  output += String(format: "%.6f", x)
  output += " "
  output += String(format: "%.9f", x / Double(int))
  return output
}

print(getFormattedTime(checkpoint2 - checkpoint1, timeLimit))

// CreepFilter2.swift
// t:   19 | V: 1.00000 | x: 1.00811 | x: 1.00842 | dx: 0.00041 | dx: 0.00040 |
// t:   99 | V: 1.00000 | x: 1.01657 | x: 1.01706 | dx: 0.00004 | dx: 0.00004 |
// t: 9999 | V: 1.00000 | x: 1.03400 |x: 1.03449 | dx: 0.00000 | dx: 0.00000 |
//
// timings for performance:
// simple = 20, efficient = 1000
// simple = 20, efficient = 10000
// simple = 20, efficient = 100000
//
// updateRate = 100 | 150, 159, 174
// updateRate = 1   | 227, 238, 258
//
// CreepFilter4.swift
// t:   19 | V: 1.00000 | x: 1.00811 | x: 1.00842 | dx: 0.00041 | dx: 0.00040 |
// t:   99 | V: 1.00000 | x: 1.01657 | x: 1.01706 | dx: 0.00004 | dx: 0.00004 |
// t: 9999 | V: 1.00000 | x: 1.03400 | x: 1.03451 | dx: 0.00000 | dx: 0.00000 |
//
// timings for performance:
// t = 1000
// t = 10000
// t = 100000
//
// SIMD2,  updateRate = 100 | 154, 159, 169
// scalar, updateRate = 100 | 144, 150, 160
// SIMD2,  updateRate = 1   | 204, 224, 243
// scalar, updateRate = 1   | 196, 212, 231

#else

let voltageSequence: [Float] = [
//  0, 0, 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 20, 20,
  0, 0, 0, 0, 1,
]

var creepFilter = CreepFilter()

for time in 0..<100 {
  var voltage: SIMD2<Float>
  if time < voltageSequence.count {
    voltage = SIMD2(repeating: voltageSequence[time])
  } else {
    voltage = SIMD2(repeating: voltageSequence.last!)
  }
  
  print()
  print("time:", time)
  print("voltage:", voltage[0])
  
  creepFilter.updateCreepRate(time: time)
  creepFilter.update(stimulus: voltage, time: time)
  
  print("creep filter:")
  for queueID in creepFilter.queues.indices {
    if queueID < 25 {
      continue
    }
    print("- queues[\(queueID)]:")
    
    let queue = creepFilter.queues[queueID]
    print("  - maxTime: \(queue.maxTime)")
    
    for sampleID in queue.startIndex..<queue.endIndex {
      // This memory access can be merged with shifting the time origin of
      // all samples. 'relativeTime' will always evaluate to zero. During the
      // very first iteration, where t = 0, there are no samples.
      //
      // First, check correctness of the existing implementation. Record all
      // simulation results to 8 decimal places. Implement the change, and
      // check that the results do not change.
      let sample = queue[sampleID]
    
      print("  - samples[\(sampleID - queue.startIndex)]:", terminator: " ")
      print(sample.dV[0], terminator: ", ")
      print(sample.time, terminator: ", ")
      print(sample.queueTime, terminator: " ")
      print()
    }
  }
}

#endif
