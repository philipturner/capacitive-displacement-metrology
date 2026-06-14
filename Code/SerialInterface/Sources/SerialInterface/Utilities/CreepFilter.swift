import Foundation

struct CreepFilter {
  static let logScaleResolution: Int = 4
  static let queueCount: Int = 33
  
  var creepConstants: SIMD2<Float> = .zero
  var previousStimulus: SIMD2<Float> = .zero
  var currentCreepRate: SIMD2<Float> = .zero
  var futureAccumulatedDrift: SIMD2<Float> = .zero
  
  var queues: [Queue] = []
  var lookupTable: LookupTable
  var timeOffset: UInt32 = .zero
  
  init() {
    for queueID in 0..<Self.queueCount {
      let shiftAmount = (Self.queueCount - 1) - queueID
      let maxTime = Self.logScaleResolution * (1 << shiftAmount)
      
      let queue = Queue(maxTime: maxTime)
      queues.append(queue)
    }
    lookupTable = LookupTable()
  }
  
  mutating func update(stimulus: SIMD2<Float>) {
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
  
  private mutating func shiftSampleTimes() -> SIMD2<Float> {
    timeOffset += 1
    
    var accumulator: SIMD2<Float> = .zero
    for queueID in queues.indices {
      let startIndex = queues[queueID].startIndex
      let endIndex = queues[queueID].endIndex
      for sampleID in startIndex..<endIndex {
        let sample = queues[queueID][sampleID]
        
        var dt = Float(timeOffset - sample.queueTime)
        dt -= sample.trueTimeOffset
        let dtInv = 1 / dt
        
        var localAccumulator: Float = 0
        if dt >= Float(LookupTable.supersamplingRate) {
          localAccumulator = dtInv
        } else {
          #if false
          let sampleCount = Float(LookupTable.supersamplingRate) * dtInv
          let loopSize = ceil(sampleCount)
          for i in 0..<Int(loopSize) {
            let denominator = dt * loopSize + Float(i)
            localAccumulator += 1 / denominator
          }
          #else
          let binID = lookupTable.binID(dt: dt)
          localAccumulator = lookupTable.bins[binID]
          #endif
        }
        accumulator += sample.dV * localAccumulator
      }
    }
    return accumulator
  }
  
  private mutating func updateCreepRate(accumulator: SIMD2<Float>) {
    currentCreepRate = accumulator * creepConstants / log(10)
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
    var dV: SIMD2<Float> = .zero
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
      let dV_squared = sample.dV * sample.dV
      let accumulator = dV_squared[0] + dV_squared[1]
      return sqrt(accumulator)
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

extension CreepFilter {
  struct LookupTable {
    static let supersamplingRate: Int = 100
    static let resolution: Int = 32
    
    var bins: [Float] = []
    
    init() {
      let binCount = 1 + Self.supersamplingRate * Self.resolution
      bins = Array(repeating: 0, count: binCount)
      
      for binID in Self.resolution..<binCount {
        let dt = Float(binID) / Float(Self.resolution)
        
        let sampleCount = Float(Self.supersamplingRate) / dt
        let loopSize = ceil(sampleCount)
        
        var weight: Float = 0
        for i in 0..<Int(loopSize) {
          let denominator = dt * loopSize + Float(i)
          weight += 1 / denominator
        }
        bins[binID] = weight
      }
    }
    
    func binID(dt: Float) -> Int {
      var rounded = dt
      rounded *= Float(Self.resolution)
      rounded += 0.5
      return Int(rounded)
    }
  }
}
