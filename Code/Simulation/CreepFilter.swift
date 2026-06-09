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
  
  func creepInducedChange(
    startTime: Int,
    subsamplingResolution: Int = 100
  ) -> Double {
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

var previousVoltage: Double = 0
var correctedVoltage: Double = 0
var simulatedPositionHighRes: Double = 0

for t in 0..<800 {
  let simulatedCreepRate = creepFilter.creepInducedChange(
    startTime: t, subsamplingResolution: 1)
  let simulatedCreepRateHighRes = creepFilter.creepInducedChange(startTime: t)
  
  var voltage: Double
//   var position: Double
//   var creepRate: Double
  if t < stepVoltageTime {
    voltage = .zero
//     position = .zero
//     creepRate = .zero
  } else if t == stepVoltageTime {
    voltage = stepVoltageAmplitude
//     position = .zero
//     creepRate = .zero
  } else {
//     let dt = Double(t) - Double(stepVoltageTime)
    voltage = stepVoltageAmplitude
//     position = stepVoltageAmplitude * (1 + creepConstant * log(dt))
//     creepRate = stepVoltageAmplitude * (creepConstant / dt)
  }
  
  func updateVoltage() {
    let dV = voltage - previousVoltage
    previousVoltage = voltage
    
    correctedVoltage += dV
    correctedVoltage -= 1.00 * simulatedCreepRate
  }
  updateVoltage()
  
  let validTimes: [Int] = [
    0, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    49, 99, 199, 399,
    799, 1599
  ]
  
  if validTimes.contains(t) {
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
    
    print("t:", pad("\(t)", length: 4), terminator: " | ")
    print("V:", display(voltage), terminator: " | ")
    print("V:", display(correctedVoltage), terminator: " | ")
    //  print("x:", display(position), terminator: " | ")
    print("x:", display(simulatedPositionHighRes), terminator: " | ")
    print("dx:", display(simulatedCreepRate), terminator: " | ")
    print("dx:", display(simulatedCreepRateHighRes), terminator: " | ")
    
    func getFormattedError() -> String {
      let error = simulatedPositionHighRes - voltage
      var output = String(format: "%.6f", error)
      
      let length = String("-X.XXXXXX").count
      output = pad(output, length: length)
      return output
    }
    
    // simulatedPosition - position from log(t) expectation of response
    // reality @ 1x:   0.002083 @ t = 49
    // reality @ 1x:   0.002110 @ t = 99
    // reality @ 10x:  0.000183 @ t = 49
    // reality @ 10x:  0.000186 @ t = 99
    // reality @ 100x: 0.000018 @ t = 49
    // reality @ 100x: 0.000018 @ t = 99
    //
    // simulatedPosition - voltage
    // reality @ 1x:   0.0156 @ t = 49
    // reality @ 1x:   0.0187 @ t = 99
    // reality @ 10x:  0.0137 @ t = 49
    // reality @ 10x:  0.0168 @ t = 99
    // reality @ 100x: 0.0135 @ t = 49
    // reality @ 100x: 0.0166 @ t = 99
    //
    // simulatedPositionHighRes - voltage
    // feedback: same creep rate as reality, reality @ 100x
    //
    // creep filter @ 1x:   -0.002034 @ t = 49  | correctedVoltage = 0.9845
    // creep filter @ 1x:   -0.002054 @ t = 99  | correctedVoltage = 0.9816
    // creep filter @ 1x:   -0.002059 @ t = 199 | correctedVoltage = 0.9789
    // creep filter @ 1x:   -0.002058 @ t = 399 | correctedVoltage = 0.9764
    //
    // creep filter @ 10x:  -0.000163 @ t = 49  | correctedVoltage = 0.9864
    // creep filter @ 10x:  -0.000165 @ t = 99  | correctedVoltage = 0.9835
    // creep filter @ 10x:  -0.000165 @ t = 199 | correctedVoltage = 0.9808
    // creep filter @ 10x:  -0.000165 @ t = 399 | correctedVoltage = 0.9783
    //
    // creep filter @ 100x: -0.000000 @ t = 49  | correctedVoltage = 0.9865
    // creep filter @ 100x: -0.000000 @ t = 99  | correctedVoltage = 0.9836
    // creep filter @ 100x: -0.000000 @ t = 199 | correctedVoltage = 0.9810
    // creep filter @ 100x: -0.000000 @ t = 399 | correctedVoltage = 0.9784
    //
    // simulatedPositionHighRes - voltage
    // feedback: reality @ 100x, creep filter @ 1x
    //
    // 1.00x creep rate: -0.002034 @ t = 49   | correctedVoltage = 0.9845
    // 1.00x creep rate: -0.002054 @ t = 99   | correctedVoltage = 0.9816
    // 1.00x creep rate: -0.002059 @ t = 199  | correctedVoltage = 0.9789
    // 1.00x creep rate: -0.002058 @ t = 399  | correctedVoltage = 0.9764
    // 1.00x creep rate: -0.002055 @ t = 799  | correctedVoltage = 0.9739
    // 1.00x creep rate: -0.002051 @ t = 1599 | correctedVoltage = 0.9715
    //
    // 0.89x creep rate: -0.000342 @ t = 49   | correctedVoltage = 0.9862
    // 0.89x creep rate: -0.000035 @ t = 99   | correctedVoltage = 0.9836
    // 0.89x creep rate:  0.000256 @ t = 199  | correctedVoltage = 0.9812
    // 0.89x creep rate:  0.000538 @ t = 399  | correctedVoltage = 0.9789
    // 0.89x creep rate:  0.000816 @ t = 799  | correctedVoltage = 0.9767
    // 0.89x creep rate:  0.001090 @ t = 1599 | correctedVoltage = 0.9745
    //
    // 0.50x creep rate:  0.005699 @ t = 49   | correctedVoltage = 0.9922
    // 0.50x creep rate:  0.007186 @ t = 99   | correctedVoltage = 0.9907
    // 0.50x creep rate:  0.008546 @ t = 199  | correctedVoltage = 0.9894
    // 0.50x creep rate:  0.009849 @ t = 399  | correctedVoltage = 0.9881
    // 0.50x creep rate:  0.011123 @ t = 799  | correctedVoltage = 0.9868
    // 0.50x creep rate:  0.012382 @ t = 1599 | correctedVoltage = 0.9855
    //
    // 0.00x creep rate:  0.013542 @ t = 49   | correctedVoltage = 1.0000
    // 0.00x creep rate:  0.016588 @ t = 99   | correctedVoltage = 1.0000
    // 0.00x creep rate:  0.019368 @ t = 199  | correctedVoltage = 1.0000
    // 0.00x creep rate:  0.022033 @ t = 399  | correctedVoltage = 1.0000
    // 0.00x creep rate:  0.024644 @ t = 799  | correctedVoltage = 1.0000
    // 0.00x creep rate:  0.027228 @ t = 1599 | correctedVoltage = 1.0000
    
    // Conclusion:
    // Do not use a constant correction factor to make the entered creep rate
    // calibrate to the true creep rate. There is just a constant offset to the
    // steady-state position that converges after ~10 iterations of t0 with
    // 0.85%/decade creep rate.
    
    print(getFormattedError(), terminator: " | ")
    print()
  }
  
  // voltage: voltage for normal operation
  // voltage: correctedVoltage for feedback
  simulatedPositionHighRes += creepFilter.update(voltage: correctedVoltage, t: t)
}
