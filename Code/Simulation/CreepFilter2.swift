import Foundation

let creepConstant: Float = 0.85e-2 / log(10)

struct Sample {
  var dV: Float
  var time: Float
}

struct SimpleCreepFilter {
  var currentResponse: Float = .zero
  var currentStimulus: Float = .zero
  var samples: [Sample] = []
  
  func creepRate(time: Float) -> Float {
    var accumulator: Float = .zero
    for sample in samples {
      let dt = time - sample.time
      guard dt >= 1 else {
        fatalError("This should never happen.")
      }
      
      accumulator += sample.dV / dt
    }
    return creepConstant * accumulator
  }
  
  // Returns the change in response.
  mutating func update(stimulus: Float, time: Float) {
    let creep_dx = creepRate(time: time)
    let dV = stimulus - currentStimulus
    currentResponse += creep_dx + dV
    currentStimulus = stimulus
    
    let sample = Sample(dV: dV, time: time)
    samples.append(sample)
  }
}

// TODO

var simpleCreepFilter = SimpleCreepFilter()
let stepVoltageAmplitude: Float = 1
let stepVoltageTime: Int = 10

for time in 0..<100 {
  let simulatedCreepRate = simpleCreepFilter.creepRate(time: Float(time))
  
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
  print("x:", display(simpleCreepFilter.currentResponse), terminator: " | ")
  print("dx:", display(creepRate), terminator: " | ")
  print("dx:", display(simulatedCreepRate), terminator: " | ")
  
  func getFormattedError() -> String {
    let error = simpleCreepFilter.currentResponse - position
    var output = String(format: "%.6f", error)
    
    let length = String("-X.XXXXXX").count
    output = pad(output, length: length)
    return output
  }
  
  print(getFormattedError(), terminator: " | ")
  print()
  
  simpleCreepFilter.update(stimulus: voltage, time: Float(time))
}
