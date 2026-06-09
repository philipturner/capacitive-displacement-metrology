import Foundation

// 1:1 correspondence of voltage to position; just using these names to
// elegantly distinguish the control and response signals.

let creepConstant: Double = 0.85e-2 / log(10)

struct CreepFilter {
  var currentVoltage: Double = .zero
  var samples: [SIMD2<Double>] = []
  
  mutating func addSample(voltage: Double, t: Int) {
    let dV = voltage - currentVoltage
    currentVoltage = voltage
    
    let sample = SIMD2(dV, Double(t))
    samples.append(sample)
  }
  
  func creepRate(t: Double) -> Double {
    var output: Double = .zero
    for sample in samples {
      let dt = t - sample[1]
      guard dt >= 1 else {
        continue
      }
      
      let dV = sample[0]
      output += dV / dt
    }
    return creepConstant * output
  }
  
  // Smoothly integrates creep over 1 unit of time.
  func positionChange(startTime: Int) -> Double {
    let subsamplingResolution: Int = 10
    
    func creepInducedChange() -> Double {
      var accumulator: Double = .zero
      for i in 0..<subsamplingResolution {
        let t = Double(startTime) + Double(i) / Double(subsamplingResolution)
        let creepRate = self.creepRate(t: t)
        accumulator += creepRate
      }
      accumulator /= Double(subsamplingResolution)
      
      return accumulator
    }
    
    func voltageInducedChange() -> Double {
      guard samples.count > 0 else {
        fatalError("Could not get latest sample.")
      }
      let latestSample = samples.last!
      let latestTime = Int(latestSample[1])
      guard latestTime == startTime else {
        fatalError("Latest sample had wrong time.")
      }
      
      let dV = latestSample[0]
      return dV
    }
    
    return voltageInducedChange() + creepInducedChange()
  }
}

var creepFilter = CreepFilter()
let stepVoltageAmplitude: Double = 1
let stepVoltageTime: Int = 10

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
  print(display(creepRate), terminator: " | ")
  print()
}
