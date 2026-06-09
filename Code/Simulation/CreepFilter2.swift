import Foundation

let creepConstant: Double = 0.85e-2 / log(10)

struct SimpleCreepFilter {
  var currentStimulus: Double = .zero
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
  
  // Returns the change in response.
  mutating func update(stimulus: Double, t: Int) -> Double {
    let creep_dx = creepRate(t: t)
    
    let dV = stimulus - currentStimulus
    currentStimulus = stimulus
    samples.append(SIMD2(dV, Double(t)))
    
    return creep_dx + dV
  }
}

// TODO
