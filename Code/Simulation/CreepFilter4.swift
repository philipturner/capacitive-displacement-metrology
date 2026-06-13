import Foundation

let timeLimit: Int = 20000
let displayResults: Bool = true
let waveTypeStep: Bool = false

// step voltage evolution:
// t:    99 | V: 1.000000 | x: 1.016570 | x: 1.017102 | dx: 0.000041 | dx: 0.000041 |
// t:  9999 | V: 1.000000 | x: 1.033996 | x: 1.034507 | dx: 0.000000 | dx: 0.000000 |
//
// sine stimulus evolution:
// t:   199 | V: -0.156435 | x: -0.004463 | x: -0.160898 | dx: 0.000000 | dx: 0.000609 |
// t: 19999 | V: -0.156435 | x: 0.019107  | x: -0.137327 | dx: 0.000000 | dx: 0.000644 |



// with latest changes:
//
// step voltage evolution:
// t:   99 | V: 1.000000 | x: 1.016570 | x: 1.017102 | dx: 0.000041 | dx: 0.000041 |
// t: 9999 | V: 1.000000 | x: 1.033996 | x: 1.034507 | dx: 0.000000 | dx: 0.000000 |
//
// sine stimulus evolution:
// t:  199 | V: -0.156435 | x: -0.004463 | x: -0.160898 | dx: 0.000000 | dx: 0.000609 |
// t: 19999 | V: -0.156435 | x: 0.019108 | x: -0.137327 | dx: 0.000000 | dx: 0.000644 |

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
  var timeOffset: UInt32 = .zero
  
  init() {
    for queueID in 0..<Self.queueCount {
      let shiftAmount = (Self.queueCount - 1) - queueID
      let maxTime = Self.logScaleResolution * (1 << shiftAmount)
      
      let queue = Queue(maxTime: maxTime)
      queues.append(queue)
    }
  }
  
  mutating func update(stimulus: VectorType) {
    // Responding to the DAC updates from the current iteration.
    var sample = Sample()
    sample.dV = stimulus - previousStimulus
    sample.trueTimeOffset = 0
    sample.queueTime = timeOffset
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
  
  // v1: (use timeOffset, do not modify samples)
  // t:  199 | V: -0.15643483 | x: -0.00446336 | x: -0.16089819 | dx: 0.00000000 | dx: 0.00060858 |
  // t:  999 | V: -0.15643483 | x: -0.00407286 | x: -0.16050769 | dx: 0.00000000 | dx: 0.00061050 |
  // t: 1999 | V: -0.15643483 | x: -0.00355036 | x: -0.15998520 | dx: 0.00000000 | dx: 0.00062859 |
  // t: 1999 | V: -0.15643483 | x: -0.00421574 | x: -0.16065058 | dx: 0.00000000 | dx: 0.00084441 | (no supersampling)
  // t: 19999 | V: -0.15643483 | x: 0.01930976 | x: -0.13712507 | dx: 0.00000000 | dx: 0.00064439 |
  // t: 19999 | V: -0.15643483 | x: 0.01913506 | x: -0.13729978 | dx: 0.00000000 | dx: 0.00064441 | (first shift to true time offset)
  // t: 19999 | V: -0.15643483 | x: 0.01912511 | x: -0.13730973 | dx: 0.00000000 | dx: 0.00064439 | (second modification)
  // t: 19999 | V: -0.15643483 | x: 0.01910781 | x: -0.13732703 | dx: 0.00000000 | dx: 0.00064441 | (third modification)
  // t: 19999 | V: -0.15643483 | x: 0.01910785 | x: -0.13732699 | dx: 0.00000000 | dx: 0.00064441 |
  
  // queueTime with v1, time with v2:
  // t:  199 | V: -0.15643483 | x: -0.00446337 | x: -0.16089821 | dx: 0.00000000 | dx: 0.00060858 |
  // t:  999 | V: -0.15643483 | x: -0.00407339 | x: -0.16050823 | dx: 0.00000000 | dx: 0.00061050 |
  // t: 1999 | V: -0.15643483 | x: -0.00355240 | x: -0.15998724 | dx: 0.00000000 | dx: 0.00062859 |
  // t: 1999 | V: -0.15643483 | x: -0.00421783 | x: -0.16065267 | dx: 0.00000000 | dx: 0.00084441 | (no supersampling)
  // t: 19999 | V: -0.15643483 | x: 0.01910741 | x: -0.13732743 | dx: 0.00000000 | dx: 0.00064441 |
  
  // v2: (decrement every sample, every iteration)
  // t:  199 | V: -0.15643483 | x: -0.00446337 | x: -0.16089821 | dx: 0.00000000 | dx: 0.00060858 |
  // t:  999 | V: -0.15643483 | x: -0.00407339 | x: -0.16050823 | dx: 0.00000000 | dx: 0.00061050 |
  // t: 1999 | V: -0.15643483 | x: -0.00355240 | x: -0.15998724 | dx: 0.00000000 | dx: 0.00062859 |
  // t: 1999 | V: -0.15643483 | x: -0.00421783 | x: -0.16065267 | dx: 0.00000000 | dx: 0.00084441 | (no supersampling)
  // t: 19999 | V: -0.15643483 | x: 0.01910741 | x: -0.13732743 | dx: 0.00000000 | dx: 0.00064441 |
  // t: 19999 | V: -0.15643483 | x: 0.01910780 | x: -0.13732703 | dx: 0.00000000 | dx: 0.00064441 | (first shift to true time offset)
  // t: 19999 | V: -0.15643483 | x: 0.01910781 | x: -0.13732703 | dx: 0.00000000 | dx: 0.00064441 | (second modification)
  // t: 19999 | V: -0.15643483 | x: 0.01910781 | x: -0.13732703 | dx: 0.00000000 | dx: 0.00064441 | (third modification)
  // t: 19999 | V: -0.15643483 | x: 0.01910785 | x: -0.13732699 | dx: 0.00000000 | dx: 0.00064441 | (fourth modification)
  
  private mutating func shiftSampleTimes() -> VectorType {
    timeOffset += 1
    
    var accumulator: VectorType = .zero
    for queueID in queues.indices {
      let startIndex = queues[queueID].startIndex
      let endIndex = queues[queueID].endIndex
      for sampleID in startIndex..<endIndex {
        let sample = queues[queueID][sampleID]
        
        var dt = Float(timeOffset - sample.queueTime)
        dt -= sample.trueTimeOffset
        let dtInv = 1 / dt
        
        var localAccumulator: Float = 0
        if dt >= Self.supersamplingRate {
          localAccumulator = dtInv
        } else {
          let sampleCount = Self.supersamplingRate * dtInv
          let loopSize = ceil(sampleCount)
          for i in 0..<Int(loopSize) {
            let denominator = dt * loopSize + Float(i)
            localAccumulator += 1 / denominator
          }
        }
        accumulator += sample.dV * localAccumulator
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
      let ready = queues[queueID].hasReadySample(timeOffset: timeOffset)
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
    var queueTime: UInt32 = .zero
    var trueTimeOffset: Float = .zero
    
    init() {
      
    }
    
    init(_ source1: Sample, _ source2: Sample) {
      dV = source1.dV + source2.dV
      queueTime = (source1.queueTime + source2.queueTime) / 2
      
      trueTimeOffset = Self.getWeightedTime(source1, source2)
      trueTimeOffset -= Float(queueTime - source1.queueTime)
    }
    
    static func getMagnitude(_ sample: Sample) -> Float {
      return vectorMagnitude(sample.dV)
    }
    
    static func getWeightedTime(
      _ source1: Sample,
      _ source2: Sample
    ) -> Float {
      guard source1.queueTime < source2.queueTime else {
        fatalError("Sources were not ordered.")
      }
      
      let relativeTime1 = source1.trueTimeOffset
      var relativeTime2 = source2.trueTimeOffset
      relativeTime2 += Float(source2.queueTime - source1.queueTime)
      
      let magnitude1 = getMagnitude(source1)
      let magnitude2 = getMagnitude(source2)
      if magnitude1 + magnitude2 < 1e-6 {
        return (relativeTime1 + relativeTime2) / 2
      }
      
      var accumulator: Float = .zero
      accumulator += relativeTime1 * magnitude1
      accumulator += relativeTime2 * magnitude2
      accumulator /= magnitude1 + magnitude2
      return accumulator
    }
  }
}

extension CreepFilter {
  struct Queue {
    static let capacity = CreepFilter.logScaleResolution + 1
    
    var maxTime: Int
    var data: [Sample]
    var startIndex: Int = .zero
    var endIndex: Int = .zero
    
    init(maxTime: Int) {
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
    
    func hasReadySample(timeOffset: UInt32) -> Bool {
      guard endIndex - startIndex >= 2 else {
        return false
      }
      
      let queueTime0 = self[startIndex + 0].queueTime
      let queueTime1 = self[startIndex + 1].queueTime
      let queueTimeCombined = (queueTime0 + queueTime1) / 2
      
      let dt = timeOffset - queueTimeCombined
      if dt > maxTime {
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
  if waveTypeStep {
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
  } else {
    let wavePeriod: Int = 40
    let phase = time % wavePeriod
    let phaseNormalized = Float(phase) / Float(wavePeriod)
    let sineValue = sin(2 * Float.pi * phaseNormalized)
    voltage = SIMD2<Float>(repeating: sineValue)
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
    if waveTypeStep {
      print("x:", display(position), terminator: " | ")
    } else {
      print("x:", display(creepFilter.futureAccumulatedDrift), terminator: " | ")
    }
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

#else

var creepFilter = CreepFilter()

for time in 0..<timeLimit {
  var voltage: SIMD2<Float>
  if waveTypeStep {
    if time < 10 {
      voltage = SIMD2(repeating: 0)
    } else {
      voltage = SIMD2(repeating: 1)
    }
  } else {
   let wavePeriod: Int = 40
   let phase = time % wavePeriod
   let phaseNormalized = Float(phase) / Float(wavePeriod)
   let sineValue = sin(2 * Float.pi * phaseNormalized)
   voltage = SIMD2<Float>(repeating: sineValue)
  }
  
  let shouldDisplay = (time > timeLimit - 10)
  
  if shouldDisplay {
    print()
    print("time:", time)
    print("voltage:", voltage[0])
  }
  
  creepFilter.update(stimulus: voltage)
  
  if shouldDisplay {
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
  
}

#endif

// v1:
/*
 time: 19999
 voltage: -0.15643483
 20 0 3.817618e-05
 20 1 -0.0001181243
 20 2 0.00019668113
 21 0 -2.7512362e-05
 21 1 -0.00024190947
 22 0 0.00041301263
 22 1 -0.0008809692
 23 0 0.00040730747
 24 0 0.00032473207
 24 1 0.0012205777
 25 0 -0.0023691414
 25 1 -0.0015111812
 26 0 0.006800699
 26 1 -0.004710259
 27 0 -0.0057653217
 27 1 0.004758358
 27 2 0.014761296
 28 0 -0.02901833
 28 1 0.047077715
 29 0 -0.0066810953
 29 1 -0.057013687
 30 0 -0.02973452
 30 1 -0.008320921
 31 0 0.012686709
 31 1 0.032352008
 32 0 0.027644923
 32 1 0.03991802
 32 2 0.061264783
 32 3 0.10967198
 creep filter:
 - queues[25]:
   - maxTime: 512
   - samples[0]: -1.1610967, 19509.908, 19519.5
   - samples[1]: -0.53369784, 19646.834, 19647.5
 - queues[26]:
   - maxTime: 256
   - samples[0]: 1.6947953, 19750.791, 19743.5
   - samples[1]: -0.86354136, 19816.668, 19807.5
   - samples[2]: -0.29755533, 19868.34, 19871.5
 - queues[27]:
   - maxTime: 128
   - samples[0]: 1.161097, 19921.342, 19919.5
 - queues[28]:
   - maxTime: 64
   - samples[0]: -1.6947951, 19941.596, 19943.5
   - samples[1]: 1.878695, 19960.094, 19959.5
 - queues[29]:
   - maxTime: 32
   - samples[0]: -0.18389976, 19972.475, 19971.5
   - samples[1]: -1.161097, 19979.635, 19979.5
 - queues[30]:
   - maxTime: 16
   - samples[0]: -0.43701616, 19985.303, 19985.5
   - samples[1]: -0.09668195, 19988.38, 19989.5
 - queues[31]:
   - maxTime: 8
   - samples[0]: 0.09668177, 19992.621, 19992.5
   - samples[1]: 0.18389976, 19994.555, 19994.5
 - queues[32]:
   - maxTime: 4
   - samples[0]: 0.11932117, 19996.0, 19996.0
   - samples[1]: 0.1337952, 19997.0, 19997.0
   - samples[2]: 0.14497313, 19998.0, 19998.0
   - samples[3]: 0.15258256, 19999.0, 19999.0
 */

// v2:
/*
 time: 19999
 voltage: -0.15643483
 20 0 3.817618e-05
 20 1 -0.0001181243
 20 2 0.00019668111
 21 0 -2.7512357e-05
 21 1 -0.00024190941
 22 0 0.0004130124
 22 1 -0.0008809688
 23 0 0.00040730723
 24 0 0.00032473123
 24 1 0.0012205754
 25 0 -0.0023691438
 25 1 -0.001511183
 26 0 0.0068006776
 26 1 -0.0047102463
 27 0 -0.0057652057
 27 1 0.004758305
 27 2 0.014760947
 28 0 -0.0290178
 28 1 0.04707864
 29 0 -0.0066814893
 29 1 -0.057012223
 30 0 -0.02973357
 30 1 -0.008319513
 31 0 0.012686733
 31 1 0.032349013
 32 0 0.027644923
 32 1 0.03991802
 32 2 0.061264783
 32 3 0.10967198
 creep filter:
 - queues[25]:
   - maxTime: 512
   - samples[0]: -1.1610967, -490.09125, -480.5
   - samples[1]: -0.53369784, -353.1656, -352.5
 - queues[26]:
   - maxTime: 256
   - samples[0]: 1.6947953, -249.20978, -256.5
   - samples[1]: -0.86354136, -183.33252, -192.5
   - samples[2]: -0.29755533, -131.66345, -128.5
 - queues[27]:
   - maxTime: 128
   - samples[0]: 1.161097, -78.660065, -80.5
 - queues[28]:
   - maxTime: 64
   - samples[0]: -1.6947951, -58.40536, -56.5
   - samples[1]: 1.878695, -39.905464, -40.5
 - queues[29]:
   - maxTime: 32
   - samples[0]: -0.18389976, -27.52377, -28.5
   - samples[1]: -1.161097, -20.365757, -20.5
 - queues[30]:
   - maxTime: 16
   - samples[0]: -0.43701616, -14.697736, -14.5
   - samples[1]: -0.09668195, -11.621107, -10.5
 - queues[31]:
   - maxTime: 8
   - samples[0]: 0.09668177, -7.378891, -7.5
   - samples[1]: 0.18389976, -5.445838, -5.5
 - queues[32]:
   - maxTime: 4
   - samples[0]: 0.11932117, -4.0, -4.0
   - samples[1]: 0.1337952, -3.0, -3.0
   - samples[2]: 0.14497313, -2.0, -2.0
   - samples[3]: 0.15258256, -1.0, -1.0
 */
