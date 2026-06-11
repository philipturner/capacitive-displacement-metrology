import Foundation

// This code is a mess now, after looking deeper into the cause of the
// numerical instability.

let creepConstant: Float = 1e-2 / log(10)
let logScaleResolution: Int = 4 // even numbers never have >1 transition/cycle
let timeOriginUpdateRate: Int = 100
typealias PreciseType = Float

let supersamplingRateEfficient: Int = 10
let capacitySimpleLowRes: Int = 100
let timeLimit: Int = 3000
let enableCreepCorrection: Bool = true

let showResults: Bool = false
let displayHighResCutoff: Int = 1100
let stimulusActiveCutoff: Int? = 1000

enum StimulusType {
  case triangleWave
  case sineWave
}
let stimulusType: StimulusType = .sineWave

//func createWavePeriods() -> [Int] {
//  var output: [Int] = []
//  for i in 2...(550 / 4) {
//    let period = i * 4
//    if period > 200 {
//      guard period % 8 == 0 else {
//        continue
//      }
//    }
//    
//    let logBase2 = log(Float(period)) / log(Float(2))
//    let nearestPower2 = round(logBase2)
//    
//    // <0.05 in log space -> <3.5%
//    // <0.10 in log space -> <7%
//    let distance = abs(logBase2 - nearestPower2)
//    if distance < 0.10 {
//      continue
//    }
//    output.append(period)
//  }
//  return output
//}
//let wavePeriods = createWavePeriods()

let wavePeriods: [Int] = [16]

for wavePeriod in wavePeriods {
  
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
//      queueTime = min(source1.queueTime, source2.queueTime)
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
//      let queueTime = min(sample0.queueTime, sample1.queueTime)
      
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
    var supersampling: Bool
    
    init(capacity: Int, supersampling: Bool = false) {
      self.buffer = SampleBuffer(capacity: capacity)
      self.supersampling = supersampling
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
      
      var accumulator: PreciseType = .zero
      buffer.forEach { sample in
        let dt = relativeTime - sample.time
        guard dt >= 1 else {
          fatalError("This should never happen.")
        }
        
        if supersampling {
          var sampleCount = max(100 / dt, 10)
          sampleCount.round(.up)
          
          var localAccumulator: Float = 0
          var i: Float = 0
          while i < sampleCount {
            let offset = i / sampleCount
            localAccumulator += 1 / (dt + offset)
            i += 1
          }
          localAccumulator /= sampleCount
          
          accumulator += PreciseType(sample.dV * localAccumulator)
        } else {
          accumulator += PreciseType(sample.dV / dt)
        }
      }
      return creepConstant * Float(accumulator)
    }
    
    mutating func shiftTimeOrigin() {
      timeOrigin += timeOriginUpdateRate
      
      buffer.shiftTimeOrigin()
    }
    
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
    var supersampling: Bool
    
    init(supersampling: Bool) {
      self.supersampling = supersampling
      
      for i in (0...33).reversed() {
        let base: Float = 2.0
        
        func getMaxTime() -> Float {
          var output = pow(base, Float(i))
          output *= Float(logScaleResolution)
          return output
        }
        
        func getCapacity() -> Int {
          var multiplier: Float
          if base != 2 {
            // queue sizes grow exponentially unless base = 2
            multiplier = 100
          } else if i == 0 {
            multiplier = base * 2
          } else {
            multiplier = base
          }
          
          var output = Int(multiplier.rounded(.up))
          output *= logScaleResolution
          return output
        }
        
        let queue = Queue(
          maxTime: getMaxTime(),
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
          
          if supersampling {
            var sampleCount = Float(supersamplingRateEfficient) / dt
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
              localAccumulator /= sampleCount
              
              accumulator += PreciseType(sample.dV * localAccumulator)
            }
          } else {
            accumulator += PreciseType(sample.dV / dt)
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
  
  // MARK: - Scripting
  
  var groundTruthFilter = SimpleCreepFilter(
    capacity: timeLimit, supersampling: true)
  var creepOffset: Float = .zero
  
#if false
  var simulationFilter = SimpleCreepFilter(
    capacity: capacitySimpleLowRes, supersampling: false)
#else
  var simulationFilter = CreepFilter(supersampling: true)
#endif
  
  func createStimulusSignal(time: Int) -> Float {
    let phase = time % wavePeriod
    let phaseNormalized = Float(phase) / Float(wavePeriod)
    
    var output: Float
    switch stimulusType {
    case .triangleWave:
      if phaseNormalized < 0.5 {
        output = 2 * phaseNormalized
      } else {
        output = 2 * (1 - phaseNormalized)
      }
      output -= 0.5
    case .sineWave:
      output = -cos(2 * Float.pi * phaseNormalized)
      output /= 2
    }
    
    if time < wavePeriod / 2 {
      output = max(output, 0)
    }
    
    if let stimulusActiveCutoff {
      let maxWaveID = stimulusActiveCutoff / wavePeriod
      let waveID = time / wavePeriod
      if waveID >= maxWaveID {
        if waveID == maxWaveID,
           phase < wavePeriod / 2 {
          output = min(output, 0)
        } else {
          output = 0
        }
      }
    }
    
    return output
  }
  
  var greatestErrors: SIMD4<Float> = .zero
  var previousLoopMiddle: Float?
  for time in 0..<timeLimit {
    let creepRate = simulationFilter.creepRate(time: time)
    if enableCreepCorrection {
      creepOffset -= creepRate
    }
    
    func fmtNumber(_ number: Double) -> String {
      var output = String(format: "%.8f", number) // 4
      if number >= 0 {
        output = " " + output
      }
      return output
    }
    
    func fmtNumber(_ number: Float) -> String {
      var output = String(format: "%.8f", number) // 4
      if number >= 0 {
        output = " " + output
      }
      return output
    }
    
    func fmtError(_ number: Float) -> String {
      var output = String(format: "%.8f", number) // 6
      if number >= 0 {
        output = " " + output
      }
      return output
    }
    
    func canDisplay() -> Bool {
      if !showResults {
        return false
      }
      
      if time < displayHighResCutoff {
        return true
      }
      
      if time == timeLimit - 1 {
        return true
      }
      
      if time % wavePeriod == 0 {
        return true
      }
      
      if time > timeLimit - 2 * wavePeriod {
        return true
      }
      
      return false
    }
    
    
    let pastStimulus = createStimulusSignal(time: max(0, time - 1))
    if canDisplay() {
      print("t:", time, terminator: " | ")
      print("V:", fmtNumber(pastStimulus), terminator: " | ")
      print("V:", fmtNumber(simulationFilter.currentStimulus), terminator: " | ")
      print("x:", fmtNumber(groundTruthFilter.currentResponse), terminator: " | ")
      print("x:", fmtNumber(simulationFilter.currentResponse), terminator: " | ")
      print("dx/dt:", fmtNumber(creepRate), terminator: " | ")
      
      let creepRate2 = groundTruthFilter.creepRate(time: time)
      print("dx/dt:", fmtNumber(creepRate2), terminator: " | ")
    }
    
    let errorStimulus = creepOffset
    let errorTarget = Float(groundTruthFilter.currentResponse) - pastStimulus
    let errorModel = Float(groundTruthFilter.currentResponse - simulationFilter.currentResponse)
    if canDisplay() {
      print("dx(stimulus):", fmtError(errorStimulus), terminator: " | ")
      print("dx(target):", fmtError(errorTarget), terminator: " | ")
      print("dx(model):", fmtError(errorModel), terminator: " | ")
      print()
    }
    
    var currentErrors = SIMD4(
      errorStimulus.magnitude,
      errorTarget.magnitude,
      errorModel.magnitude,
      0)
    
    func getHysteresisWidth() -> Float? {
      guard wavePeriod % 4 == 0 else {
        fatalError("Wave period not divisible.")
      }
      let phase = time % wavePeriod
      guard (phase % (wavePeriod / 2)) == (wavePeriod / 4 + 1) else {
        return nil
      }
      
      let currentLoopMiddle = Float(groundTruthFilter.currentResponse)
      defer { previousLoopMiddle = currentLoopMiddle }
      
      if let previousLoopMiddle {
        return abs(currentLoopMiddle - previousLoopMiddle)
      } else {
        return nil
      }
    }
    
    if let hysteresisWidth = getHysteresisWidth() {
      currentErrors[3] = hysteresisWidth
    }
    
    // Skip the first few cycles to make it settle.
    if time / wavePeriod > 2 {
      greatestErrors.replace(
        with: currentErrors, where: currentErrors .> greatestErrors)
    }
    
        if time == 1015 || time == 1016 || time == 1017 || time == 1018 {
          print()
          print()
          print()
          print("============")
          print("t = \(time)")
          print("============")
          print(fmtError(errorModel))
          
          print()
          print("simulation filter:")
          for queueID in simulationFilter.queues.indices {
            if queueID < 24 {
              continue
            }
            print("- queues[\(queueID)]:")
            
            let queue = simulationFilter.queues[queueID]
            print("  - maxTime: \(queue.maxTime)")
            
            var sampleID: Int = 0
            queue.buffer.forEach { sample in
              let dt = Float(time - simulationFilter.timeOrigin)
              
              print("  - samples[\(sampleID)]:", terminator: " ")
              print(sample.dV, terminator: ", ")
              print(sample.time - dt, terminator: ", ")
              print(sample.queueTime - dt, terminator: " ")
              print()
              
              sampleID += 1
            }
          }
          
          func getSum1() -> Float {
            var output: Float = .zero
            for queueID in 0..<(simulationFilter.queues.count - 5) {
              let queue = simulationFilter.queues[queueID]
              queue.buffer.forEach { sample in
                output += sample.dV
              }
            }
            return output
          }
          
          func getSum2() -> Float {
            var output: Float = .zero
            for queueID in (simulationFilter.queues.count - 5)..<simulationFilter.queues.count {
              let queue = simulationFilter.queues[queueID]
              queue.buffer.forEach { sample in
                output += sample.dV
              }
            }
            return output
          }
          
          print()
          print(getSum1())
          print(getSum2())
          print(getSum1() + getSum2())
        }
    
    let stimulus = createStimulusSignal(time: time)
    groundTruthFilter.update(stimulus: stimulus + creepOffset, time: time)
    simulationFilter.update(stimulus: stimulus + creepOffset, time: time)
  }
  
  print(
    enableCreepCorrection,
    logScaleResolution,
    supersamplingRateEfficient,
    wavePeriod,
    String(format: "%.6f", greatestErrors[1]),
    String(format: "%.6f", greatestErrors[3]))
}
