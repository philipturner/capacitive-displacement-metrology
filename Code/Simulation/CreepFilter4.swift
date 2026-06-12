import Foundation

struct CreepFilter {
  static let logScaleResolution: Int = 4
  static let queueCount: Int = 33
  static let supersamplingRate: Float = 10
  
  static var creepConstants = SIMD2<Float>(1e-2, 1e-2) // per decade
  
  var creepRateUpdated: Bool = false
  var currentCreepRate = SIMD2<Float>(repeating: -1000)
  var accumulatedDrift: SIMD2<Float> = .zero
  var currentStimulus: SIMD2<Float> = .zero
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
    
    var accumulator: SIMD2<Float> = .zero
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
        let dt_recip = 1 / dt
        
        let sampleCount = Float(Self.supersamplingRate) * dt_recip
        if sampleCount <= 1 {
          accumulator += sample.dV * dt_recip
        } else {
          let loopSize = ceil(sampleCount)
          let loopSize_recip = 1 / loopSize
          var localAccumulator: Float = .zero
          
          // C++ for (float i = 0; i < sampleCount; ++i)
          var i: Float = 0
          while i < loopSize {
            let offset = i * loopSize_recip
            localAccumulator += 1 / (dt + offset)
            i += 1
          }
          localAccumulator += loopSize_recip
          
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
  
  mutating func shiftTimeOrigin() {
    timeOrigin += 1
    
    for queueID in queues.indices {
      queues[queueID].shiftTimeOrigin()
    }
  }
  
  mutating func update(stimulus: SIMD2<Float>, time: Int) {
    guard creepRateUpdated else {
      fatalError("Creep rate was not updated.")
    }
    accumulatedDrift += currentCreepRate
    creepRateUpdated = false
    currentCreepRate = SIMD2(repeating: -1000)
    
    let dV = stimulus - currentStimulus
    currentStimulus = stimulus
    
    var sample = Sample()
    sample.dV = dV
    sample.time = getRelativeTime(time)
    sample.queueTime = getRelativeTime(time)
    
    let queueID = Self.queueCount - 1
    queues[queueID].insert(sample)
    
    shiftDelayLine(time: time)
    shiftTimeOrigin()
  }
}

extension CreepFilter {
  struct Sample {
    var dV: SIMD2<Float> = .zero
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
      let dV_squared = sample.dV * sample.dV
      let accumulator = dV_squared[0] + dV_squared[1]
      return accumulator
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
        data[slotID].time -= 1
        data[slotID].queueTime -= 1
      }
    }
  }
}
