import Foundation

let timeLimit: Int = 10000
let displayResults: Bool = false

// MARK: - Data Type Switching

#if true

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
  return sqrt(accumulator)
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
  
  static var creepConstants = vectorInit(repeating: 0.85e-2) // per decade
  
  var previousStimulus: VectorType = .zero
  var currentCreepRate : VectorType = .zero
  var futureAccumulatedDrift: VectorType = .zero
  
  var queues: [Queue] = []
  
  init() {
    for queueID in 0..<Self.queueCount {
      let shiftAmount = (Self.queueCount - 1) - queueID
      let maxTime = Self.logScaleResolution * (1 << shiftAmount)
      
      let queue = Queue(maxTime: Float(maxTime))
      queues.append(queue)
    }
  }
  
  mutating func update(stimulus: VectorType) {
    // Responding to the DAC updates from the current iteration.
    var sample = Sample()
    sample.dV = stimulus - previousStimulus
    sample.time = 0
    sample.queueTime = 0
    previousStimulus = stimulus
    
    let queueID = Self.queueCount - 1
    queues[queueID].insert(sample)
    
    // Preparing the state for the next loop iteration (don't access these
    // variables any more during the calling iteration).
    let accumulator = shiftSampleTimes()
    updateCreepRate(accumulator: accumulator)
    updateQueues()
    
    futureAccumulatedDrift += currentCreepRate
  }
  
  private mutating func shiftSampleTimes() -> VectorType {
    var accumulator: VectorType = .zero
    for queueID in queues.indices {
      let startIndex = queues[queueID].startIndex
      let endIndex = queues[queueID].endIndex
      for sampleID in startIndex..<endIndex {
        var sample = queues[queueID][sampleID]
        sample.time += 1
        sample.queueTime += 1
        queues[queueID][sampleID] = sample
        
        let dt = sample.time
        let dtInv = 1 / dt
        let sampleCount = Float(Self.supersamplingRate) * dtInv
        
        if sampleCount <= 1 {
          accumulator += sample.dV * dtInv
        } else {
          let loopSize = ceil(sampleCount)
          let loopSizeInv = 1 / loopSize
          var localAccumulator: Float = .zero
          
          #if false
          // C++ for (float i = 0; i < sampleCount; ++i)
          var i: Float = 0
          while i < loopSize {
            let offset = i * loopSizeInv
            localAccumulator += 1 / (dt + offset)
            i += 1
          }
          #else
          
          // Integer loop seems faster on Mac, but that's with a very different
          // CPU architecture. We will only know for sure what's fastest when
          // tested on the Teensy.
          for i in 0..<Int(loopSize) {
            let offset = Float(i) * loopSizeInv
            localAccumulator += 1 / (dt + offset)
          }
          #endif
          localAccumulator *= loopSizeInv
          
          accumulator += sample.dV * localAccumulator
        }
      }
    }
    return accumulator
  }
  
  private mutating func updateCreepRate(accumulator: VectorType) {
    let creepConstants = Self.creepConstants / log(10) // C++ M_LN10
    currentCreepRate = accumulator * creepConstants
  }
  
  private mutating func updateQueues() {
    var removesDone: Int = 0
    let maxQueueID = Self.queueCount - 1
    for queueID in (0...maxQueueID).reversed() {
      let ready = queues[queueID].hasReadySample()
      guard ready else {
        continue
      }
      
      let removed = queues[queueID].removeReady()
      
      if queueID > 0 {
        queues[queueID - 1].insert(removed)
      }
      
      removesDone += 1
    }
    
    if removesDone > 1 {
      fatalError("More than one remove happened.")
    }
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
    static let capacity = CreepFilter.logScaleResolution + 1
    
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
    
    func hasReadySample() -> Bool {
      guard endIndex - startIndex >= 2 else {
        return false
      }
      
      let queueTime0 = self[startIndex + 0].queueTime
      let queueTime1 = self[startIndex + 1].queueTime
      let queueTimeCombined = (queueTime0 + queueTime1) / 2
      
      if queueTimeCombined > maxTime {
        return true
      } else {
        return false
      }
    }
    
    mutating func removeReady() -> Sample {
      let sample0 = self[startIndex + 0]
      let sample1 = self[startIndex + 1]
      startIndex += 2
      
      return Sample(sample0, sample1)
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
    let output = String(format: "%.6f", vectorFirst(number))
    return output
  }
  
  if displayResults {
    print("t:", pad("\(time)", length: 4), terminator: " | ")
    print("V:", display(voltage), terminator: " | ")
    
    let simulatedPosition = voltage + creepFilter.futureAccumulatedDrift
    print("x:", display(position), terminator: " | ")
    print("x:", display(simulatedPosition), terminator: " | ")
    
    let simulatedCreepRate = creepFilter.currentCreepRate
    print("dx:", display(creepRate), terminator: " | ")
    print("dx:", display(simulatedCreepRate), terminator: " | ")
    print()
  }
  
  creepFilter.update(stimulus: voltage)
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
//
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
//
//
//
// CreepFilter.swift, after optimizations:
// t:   19 | V: 1.00000 | x: 1.00811 | x: 1.00842 | dx: 0.00041 | dx: 0.00040 |
// t:   99 | V: 1.00000 | x: 1.01657 | x: 1.01706 | dx: 0.00004 | dx: 0.00004 |
// t: 9999 | V: 1.00000 | x: 1.03400 | x: 1.03451 | dx: 0.00000 | dx: 0.00000 |
//
// timings for performance:
// t = 1000
// t = 10000
// t = 100000
//
// SIMD2  | 145, 162, 179
// scalar | 178, 188, 195
//
// adding placeholder between dV and time for scalar, to make stride = 16 bytes:
// scalar | 145, 157, 175

#else

let voltageSequence: [Float] = [
//  0, 0, 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 20, 20,
  0, 0, 0, 0, 1,
]

var creepFilter = CreepFilter()

for time in 0..<timeLimit {
  var voltage: SIMD2<Float>
//  if time < voltageSequence.count {
//    voltage = SIMD2(repeating: voltageSequence[time])
//  } else {
//    voltage = SIMD2(repeating: voltageSequence.last!)
//  }
  
  if time < 10 {
    voltage = SIMD2(repeating: 0)
  } else {
    voltage = SIMD2(repeating: 1)
  }
  
  print()
  print("time:", time)
  print("voltage:", voltage[0])
  
  creepFilter.update(stimulus: voltage)
  
  print("creep filter:")
  for queueID in creepFilter.queues.indices {
    if queueID < 25 {
      continue
    }
    print("- queues[\(queueID)]:")
    
    let queue = creepFilter.queues[queueID]
    print("  - maxTime: \(queue.maxTime)")
    
    for sampleID in queue.startIndex..<queue.endIndex {
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
