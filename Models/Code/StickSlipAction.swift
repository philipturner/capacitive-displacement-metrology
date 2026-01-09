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
//
// exemplary velocities:
//   coarse approach woodpecker algorithm: 1.47 μm/s
//   rising edge of 1 kHz triangle wave: 816 μm/s
//   maximum slew rate, slip-inducing action: 14.4 mm/s

struct System {
  // Allowed range: -425 V to 425 V
  var controlVoltage: Float = .zero
  
  var piezoPosition: Float = .zero
  
  var piezoForce: Float {
    let expectedPosition = controlVoltage * 80e-12 * 6
    let remainingDistance = expectedPosition - piezoPosition
    return 1.47e9 * remainingDistance
  }
}

var system = System()
system.controlVoltage = 425
system.piezoPosition = -425 * 80e-12 * 6
print(system.piezoForce)
