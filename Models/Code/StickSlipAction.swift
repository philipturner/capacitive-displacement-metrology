import Foundation

// force behavior in static mode
//   reaction force = pulling force
//   unless pulling force > μ_s N
//   then switch to kinetic mode
//
// force behavior in kinetic mode
//   reaction force = μ_k N
//   unless relative surface velocity < threshold (Δv_thres)
//   then Δv immediately snaps to 0 (by changing the slider's velocity)
//   and switch to static mode
//
// combinatorial space:
//   μ_k ∈ {0.3, 0.4, 0.5}
//   Δv_thres ∈ {1e-5, 1e-4, 1e-3, 1e-2} m/s
//   gravity ∈ {positive, negative} direction
//
// exemplary velocities:
//   coarse approach woodpecker algorithm: 1.47 μm/s
//   rising edge of 1 kHz triangle wave: 816 μm/s
//   maximum slew rate, slip-inducing action: 14.4 mm/s
//
// improvements to include velocity damping sourced from
// https://scholarlypublications.universiteitleiden.nl/handle/1887/18057

struct System {
  // Allowed range: -425 V to 425 V
  // For simplicity, 0 V to 850 V is also permitted
  var controlVoltage: Float = .zero
  
  static let piezoConstant: Float = 80e-12 * 6
  static let piezoMass: Float = 3 * 1.02e-3
  var piezoPosition: Float = .zero
  static let piezoQualityFactor: Float = 1000
  static let piezoStiffness: Float = 1.47e9
  var piezoVelocity: Float = .zero
  
  static let sliderMass: Float = 8.94e-3
  // sliderVelocity = piezoVelocity
  
  func piezoForce() -> Float {
    let expectedPosition = controlVoltage * System.piezoConstant
    let deltaX = piezoPosition - expectedPosition
    return -System.piezoStiffness * deltaX
  }
  
  func dampingForce(engagedMass: Float) -> Float {
    var dampingCoefficient = 1 / System.piezoQualityFactor
    dampingCoefficient *= (System.piezoStiffness * engagedMass).squareRoot()
    return -dampingCoefficient * piezoVelocity
  }
  
  // No friction force yet (which derives from magnetic normal force)
  // No gravitational force yet (where sign matters)
  mutating func integrate(timeStep: Float) {
    let engagedMass = System.piezoMass + System.sliderMass
    var totalForce = piezoForce()
    totalForce += dampingForce(engagedMass: engagedMass)
    
    piezoVelocity += timeStep * totalForce / engagedMass
    piezoPosition += timeStep * piezoVelocity
  }
}

struct Format {
  static func format(voltage: Float) -> String {
    var output = String(format: "%.1f", voltage)
    while output.count < "-425.0".count {
      output = " " + output
    }
    return output
  }

  static func format(position: Float) -> String {
    var output = String(format: "%.1f", position / 1e-9)
    while output.count < "-1000.0".count {
      output = " " + output
    }
    return output
  }
  
  static func format(velocity: Float) -> String {
    var output = String(format: "%.1f", velocity / 1e-6)
    while output.count < "-10000.0".count {
      output = " " + output
    }
    return output
  }
}

// MARK: - Script

var system = System()
for i in 1...10000 {
  let time = Float(i) * 1e-6
  let slewRate: Float = 850 / 500e-6
  let straightLineVoltage = time * slewRate
  
  #if true
  // Triangle wave at the maximum slew rate.
  let quotient = Int((straightLineVoltage / 850).rounded(.down))
  let remainder = straightLineVoltage - Float(quotient) * 850
  if quotient % 2 == 0 {
    system.controlVoltage = remainder
  } else {
    system.controlVoltage = 850 - remainder
  }
  #else
  system.controlVoltage = min(straightLineVoltage, 850)
  #endif
  
  system.integrate(timeStep: 1e-6)
  
  if i % 2 == 0 {
    print("t = \(i) μs", terminator: " | ")
    print(Format.format(voltage: system.controlVoltage), "V", terminator: " | ")
    print(Format.format(position: system.piezoPosition), "nm", terminator: " | ")
    print(Format.format(velocity: system.piezoVelocity), "μm/s")
  }
}
print("expected position:", system.controlVoltage * System.piezoConstant / 1e-9, "nm")
