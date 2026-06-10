import Foundation

// numTimeSteps = 10000
// logScaleResolution = 3 -> 10% error relative to creep
// logScaleResolution = 20 -> 1% error relative to creep
// error relative to creep has vanished to 0.02% after fixing the systematic error in the code
let creepConstant: Float = 0.85e-2 / log(10)
let logScaleResolution: Int = 4
let timeLimitSimple: Int = 100
let numTimeSteps: Int = 10000
typealias PreciseType = Float

// MARK: - Simple Creep Filter

struct Sample {
  var dV: Float
  
  // runs out of precision after 201 seconds
  //
  // idea: run an operation to subtract 1000 from all samples, which overlaps
  // with a cycle where 1 or less bins transitioned
  var time: Float
  
  var queueTime: Float
  
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

struct SimpleCreepFilter {
  var currentResponse: PreciseType = .zero
  var currentStimulus: Float = .zero
  var samples: [Sample] = []
  
  func creepRate(time: Float) -> Float {
    var accumulator: PreciseType = .zero
    for sample in samples {
      let dt = time - sample.time
      guard dt >= 1 else {
        fatalError("This should never happen.")
      }
      
      accumulator += PreciseType(sample.dV / dt)
    }
    return creepConstant * Float(accumulator)
  }
  
  // Returns the change in response.
  mutating func update(stimulus: Float, time: Float) {
    let creep_dx = creepRate(time: time)
    let dV = stimulus - currentStimulus
    currentResponse += PreciseType(creep_dx + dV)
    currentStimulus = stimulus
    
    let sample = Sample(dV: dV, time: time)
    samples.append(sample)
  }
}

// MARK: - Efficient Creep Filter

struct Queue {
  var maxTime: Float
  var samples: [Sample] = [] // eventually a ring buffer
  
  init(maxTime: Float) {
    self.maxTime = maxTime
  }
  
  mutating func removeFirst(time: Float) -> Sample? {
    guard samples.count >= 2 else {
      return nil
    }
    
    let sample0 = samples[0]
    let sample1 = samples[1]
    let queueTime = (sample0.queueTime + sample1.queueTime) / 2
    
    // Arbitrary choice for threshold: average time vs. time of samples[1]
    // The former gives a more consistent distribution of samples across the
    // queues.
    let dt = time - queueTime
    if dt > maxTime {
      samples.removeFirst(2)
      return Sample(sample0, sample1)
    } else {
      return nil
    }
  }
  
  mutating func insert(_ sample: Sample) {
    samples.append(sample)
  }
}

struct CreepFilter {
  var currentResponse: PreciseType = .zero
  var currentStimulus: Float = .zero
  var queues: [Queue] = []
  
  init() {
    for i in (0...20).reversed() {
      let maxTime = logScaleResolution * (1 << i)
      let queue = Queue(maxTime: Float(maxTime))
      queues.append(queue)
    }
  }
  
  func creepRate(time: Float) -> Float {
    var accumulator: PreciseType = .zero
    for queue in queues {
      for sample in queue.samples {
        let dt = time - sample.time
        guard dt >= 1 else {
          fatalError("This should never happen.")
        }
        
        accumulator += PreciseType(sample.dV / dt)
      }
    }
    return creepConstant * Float(accumulator)
  }
  
  mutating func shiftSamples(time: Float) {
    var removesDone: Int = 0
    for queueID in queues.indices.reversed() {
      let removed = queues[queueID].removeFirst(time: time)
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
      
      queues[queueID - 1].insert(removed)
      
      // Limit the number of removal operations per cycle. The infrequent
      // events where multiple bins switch will be spread out over the few
      // following cycles.
      removesDone += 1
      if removesDone >= 4 {
        break
      }
    }
  }
  
  mutating func update(stimulus: Float, time: Float) {
    let creep_dx = creepRate(time: time)
    let dV = stimulus - currentStimulus
    currentResponse += PreciseType(creep_dx + dV)
    currentStimulus = stimulus
    
    let sample = Sample(dV: dV, time: time)
    queues[queues.count - 1].insert(sample)
    
    shiftSamples(time: time)
  }
}

// MARK: - Testing

#if true

var simpleCreepFilter = SimpleCreepFilter()
var creepFilter = CreepFilter()
let stepVoltageAmplitude: Float = 1
let stepVoltageTime: Int = 10
var errorSimple: Float = .zero
var errorEfficient: Float = .zero

for time in 0..<numTimeSteps {
  let simulatedCreepRate = simpleCreepFilter.creepRate(time: Float(time))
  let simulatedCreepRate2 = creepFilter.creepRate(time: Float(time))
  
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
    let output = String(format: "%.4f", number)
    return output
  }
  
  print("t:", pad("\(time)", length: 4), terminator: " | ")
  print("V:", display(voltage), terminator: " | ")
  print("x:", display(position), terminator: " | ")
  print("x:", display(Float(simpleCreepFilter.currentResponse)), terminator: " | ")
  print("x:", display(Float(creepFilter.currentResponse)), terminator: " | ")
  print("dx:", display(creepRate), terminator: " | ")
  print("dx:", display(simulatedCreepRate), terminator: " | ")
  print("dx:", display(simulatedCreepRate2), terminator: " | ")
  
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
  
  if time < timeLimitSimple {
    simpleCreepFilter.update(stimulus: voltage, time: Float(time))
  }
  creepFilter.update(stimulus: voltage, time: Float(time))
}

#endif

#if false

let voltageSequence: [Float] = [
  0, 0, 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 20, 20,
//  0, 0, 0, 0, 1,
]

var creepFilter = CreepFilter()

for time in 0..<10000 {
  var voltage: Float
  if time < voltageSequence.count {
    voltage = voltageSequence[time]
  } else {
    voltage = voltageSequence.last!
  }
  
  print()
  print("time:", time)
  print("voltage:", voltage)
  
  creepFilter.update(stimulus: voltage, time: Float(time))
  
  print("creep filter:")
  for queueID in creepFilter.queues.indices {
    print("- queues[\(queueID)]:")
    
    let queue = creepFilter.queues[queueID]
    print("  - maxTime: \(queue.maxTime)")
    
    for sampleID in queue.samples.indices {
      let sample = queue.samples[sampleID]
      print("  - samples[\(sampleID)]:", terminator: " ")
      print(sample.dV, terminator: ", ")
      print(sample.time, terminator: " ")
      print(sample.queueTime, terminator: " ")
      
      let dt1 = Float(time) - sample.time
      let dt2 = Float(time) - sample.queueTime
      print("(\(-dt1), \(-dt2))")
    }
  }
  
  func getSum() -> Float {
    var output: Float = .zero
    for queue in creepFilter.queues {
      for sample in queue.samples {
        output += sample.dV
      }
    }
    return output
  }
  print("sum:", getSum())
}

#endif
