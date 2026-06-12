import Foundation

struct CreepFilter {
  static let logScaleResolution: Int = 4
  static let queueCount: Int = 33
  static let supersamplingRate: Int = 10
  
  static let timeOriginUpdateRate: Int = 100
  static let maxShiftsPerCycle: Int = 6
  
  static var creepConstantX: Float = 1e-2 // per decade
  static var creepConstantY: Float = 1e-2 // per decade
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
    
    // C++ const T& operator[](size_t index) const
    subscript(index: Int) -> Sample {
      _read {
        let slotID = (startIndex + index) % Self.capacity
        yield data[slotID]
      }
    }
    
    mutating func insert(_ sample: Sample) {
      if endIndex - startIndex >= Self.capacity {
        fatalError("Exceeded capacity of ring buffer.")
      }
      
      data[endIndex % Self.capacity] = sample
      endIndex += 1
    }
    
    func hasReadySample(time: Float) -> Bool {
      guard endIndex - startIndex >= 2 else {
        return false
      }
      
      let queueTime0 = self[0].queueTime
      let queueTime1 = self[1].queueTime
      let queueTimeCombined = (queueTime0 + queueTime1) / 2
      
      let dt = time - queueTimeCombined
      if dt > maxTime {
        return true
      } else {
        return false
      }
    }
    
    mutating func removeReady(time: Float) -> Sample? {
      let sample0 = self[0]
      let sample1 = self[1]
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
