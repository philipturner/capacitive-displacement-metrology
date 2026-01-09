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

struct System {
  // Allowed range: -425 V to 425 V
  // For simplicity, 0 to 850 V is also permitted
  var controlVoltage: Float = .zero
  
  static let piezoConstant: Float = 80e-12 * 6
  static let piezoMass: Float = 3 * 1.02e-3
  var piezoPosition: Float = .zero
  static let piezoStiffness: Float = 1.47e9
  var piezoVelocity: Float = .zero
  
  static let sliderMass: Float = 8.94e-3
  // sliderVelocity = piezoVelocity
  
  var piezoForce: Float {
    let expectedPosition = controlVoltage * System.piezoConstant
    let remainingDistance = expectedPosition - piezoPosition
    return System.piezoStiffness * remainingDistance
  }
  
  // No friction force yet (which derives from magnetic normal force)
  // No gravitational force yet (where sign matters)
  mutating func integrate(timeStep: Float) {
    let engagedMass: Float = System.piezoMass + System.sliderMass
    piezoVelocity += timeStep * piezoForce / engagedMass
    piezoPosition += timeStep * piezoVelocity
  }
}

var system = System()
//system.controlVoltage = 850
for i in 1...30 {
  let time = Float(i) * 1e-6
  let straightLineVoltage = time * 30e6
  
  // Triangle wave at the maximum slew rate.
  let quotient = Int((straightLineVoltage / 850).rounded(.down))
  let remainder = straightLineVoltage - Float(quotient) * 850
  if quotient % 2 == 0 {
    system.controlVoltage = remainder
  } else {
    system.controlVoltage = 850 - remainder
  }
  
  system.integrate(timeStep: 1e-6)
  print("t = \(i) μs", terminator: " | ")
  print(system.controlVoltage, "V", terminator: " | ")
  print(system.piezoPosition / 1e-9, "nm", terminator: " | ")
  print(system.piezoVelocity / 1e-6, "μm/s")
}
print(system.controlVoltage * System.piezoConstant / 1e-9, "nm")
