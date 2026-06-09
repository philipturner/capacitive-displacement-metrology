import Foundation

// 1:1 correspondence of voltage to position; just using these names to
// elegantly distinguish the control and response signals.

let creepConstant: Double = 0.85e-2 / log(10)

struct CreepFilter {
  var currentVoltage: Double = .zero
  var samples: [SIMD2<Double>] = []
  
  func creepRate(t: Double) -> Double {
    var output: Double = .zero
    for sample in samples {
      let dt = t - sample[1]
      guard dt >= 1 else {
        fatalError("This should never happen.")
      }
      
      let dV = sample[0]
      output += dV / dt
    }
    return creepConstant * output
  }
  
  private func creepInducedChange(startTime: Int) -> Double {
    let subsamplingResolution: Int = 1
    
    var accumulator: Double = .zero
    for i in 0..<subsamplingResolution {
      let t = Double(startTime) + Double(i) / Double(subsamplingResolution)
      let creepRate = self.creepRate(t: t)
      accumulator += creepRate
    }
    accumulator /= Double(subsamplingResolution)
    
    return accumulator
  }
  
  // Returns the change in position.
  mutating func update(voltage: Double, t: Int) -> Double {
    let creep_dx = creepInducedChange(startTime: t)
    
    let dV = voltage - currentVoltage
    currentVoltage = voltage
    samples.append(SIMD2(dV, Double(t)))
    
    return creep_dx + dV
  }
}

var creepFilter = CreepFilter()
let stepVoltageAmplitude: Double = 1
let stepVoltageTime: Int = 10

var simulatedPosition: Double = 0

for t in 0..<100 {
  var voltage: Double
  var position: Double
  var creepRate: Double
  
  if t < stepVoltageTime {
    voltage = .zero
    position = .zero
    creepRate = .zero
  } else if t == stepVoltageTime {
    voltage = stepVoltageAmplitude
    position = .zero
    creepRate = .zero
  } else {
    let dt = Double(t) - Double(stepVoltageTime)
    voltage = stepVoltageAmplitude
    position = stepVoltageAmplitude * (1 + creepConstant * log(dt))
    creepRate = stepVoltageAmplitude * (creepConstant / dt)
  }
  
  let simulatedCreepRate = creepFilter.creepRate(t: Double(t))
  
  func pad(_ string: String, length: Int) -> String {
    var output = string
    while output.count < length {
      output = " " + output
    }
    return output
  }
  func display(_ number: Double) -> String {
    let output = String(format: "%.4f", number)
    return output
  }
  
  print(pad("\(t)", length: 4), terminator: " | ")
  print(display(voltage), terminator: " | ")
  print(display(position), terminator: " | ")
  print(display(simulatedPosition), terminator: " | ")
  print(display(creepRate), terminator: " | ")
  print(display(simulatedCreepRate), terminator: " | ")
  
  func getFormattedError() -> String {
    let error = simulatedPosition - position
    var output = String(format: "%.5f", error)
    
    let length = String("-X.XXXXX").count
    output = pad(output, length: length)
    return output
  }
  
  // subsampling 1:  0.00211 @ t = 99
  // subsampling 10: 0.00019 @ t = 99
  print(getFormattedError(), terminator: " | ")
  print()
  
  simulatedPosition += creepFilter.update(voltage: voltage, t: t)
}
