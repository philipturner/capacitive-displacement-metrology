import Foundation

let creepConstant: Float = 0.85e-2 / log(10)
let logScaleResolution: Int = 4 // even numbers never have >1 transition/cycle
let timeLimitSimple: Int = 100
let numTimeSteps: Int = 10000 + 1
typealias PreciseType = Float

let timeOriginUpdateRate: Int = 1000

// MARK: - Simple Creep Filter

struct Sample {
  var dV: Float
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
  var timeOrigin: Int = .zero
  var samples: [Sample] = []
  
  func creepRate(time: Int) -> Float {
    let relativeTime = Float(time - timeOrigin)
    
    var accumulator: PreciseType = .zero
    for sample in samples {
      let dt = relativeTime - sample.time
      guard dt >= 1 else {
        fatalError("This should never happen.")
      }
      
      accumulator += PreciseType(sample.dV / dt)
    }
    return creepConstant * Float(accumulator)
  }
  
  mutating func shiftTimeOrigin() {
    timeOrigin += timeOriginUpdateRate
    
    for sampleID in samples.indices {
      samples[sampleID].time -= Float(timeOriginUpdateRate)
      samples[sampleID].queueTime -= Float(timeOriginUpdateRate)
    }
  }
  
  // Returns the change in response.
  mutating func update(stimulus: Float, time: Int) {
    let creep_dx = creepRate(time: time)
    let dV = stimulus - currentStimulus
    currentResponse += PreciseType(creep_dx + dV)
    currentStimulus = stimulus
    
    let relativeTime = Float(time - timeOrigin)
    let sample = Sample(dV: dV, time: relativeTime)
    samples.append(sample)
    
    if relativeTime > Float(timeOriginUpdateRate) {
      shiftTimeOrigin()
    }
  }
}

// MARK: - Efficient Creep Filter

// 103-112 ns execution time so far

struct Queue {
  // TODO: Finish code development by changing this to a ring buffer.
  var maxTime: Float
  var samples: [Sample] = [] // eventually a ring buffer
  var capacity: Int
  
  init(maxTime: Float, capacity: Int) {
    self.maxTime = maxTime
    self.capacity = capacity
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
    if samples.count == capacity {
      fatalError("Exceeded capacity.")
    }
    samples.append(sample)
  }
}

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
      for sample in queue.samples {
        let dt = relativeTime - sample.time
        accumulator += PreciseType(sample.dV / dt)
      }
    }
    return creepConstant * Float(accumulator)
  }
  
  mutating func shiftTimeOrigin() {
    timeOrigin += timeOriginUpdateRate
    
    for queueID in queues.indices {
      for sampleID in queues[queueID].samples.indices {
        var sample = queues[queueID].samples[sampleID]
        sample.time -= Float(timeOriginUpdateRate)
        sample.queueTime -= Float(timeOriginUpdateRate)
        queues[queueID].samples[sampleID] = sample
      }
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
      
      queues[queueID - 1].insert(removed)
      
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

var timeCheckpoint1 = Date().timeIntervalSince1970
var timeCheckpoint2: Double = 0
var timeCheckpoint3: Double = 0

for time in 0..<numTimeSteps {
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
  
  if time == timeLimitSimple {
    timeCheckpoint2 = Date().timeIntervalSince1970
  }
  
  #if true
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
  #endif
  
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
print(getFormattedTime(timeCheckpoint2 - timeCheckpoint1, timeLimitSimple))
print(getFormattedTime(timeCheckpoint3 - timeCheckpoint2, numTimeSteps - timeLimitSimple))

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
    
    for sampleID in queue.samples.indices {
      let sample = queue.samples[sampleID]
      print("  - samples[\(sampleID)]:", terminator: " ")
      print(sample.dV, terminator: ", ")
      print(sample.time, terminator: " ")
      print(sample.queueTime, terminator: " ")
      
      let dt1 = Float(time - creepFilter.timeOrigin) - sample.time
      let dt2 = Float(time - creepFilter.timeOrigin) - sample.queueTime
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
