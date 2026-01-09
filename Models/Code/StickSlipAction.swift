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
//   INCORRECT
//
// combinatorial space:
//   μ_k ∈ {0.3, 0.4, 0.5}
//   Δv_thres ∈ {1e-5, 1e-4, 1e-3, 1e-2} m/s | INCORRECT
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
  
  static let normalForce: Float = 2.22
  static let coefficientStatic: Float = 0.5
  static let coefficientKinetic: Float = 0.4
  
  static let piezoConstant: Float = 80e-12 * 6
  static let piezoMass: Float = 3 * 1.02e-3
  var piezoPosition: Float = .zero
  static let piezoQualityFactor: Float = 1000
  static let piezoStiffness: Float = 1.47e9
  var piezoVelocity: Float = .zero
  
  static let sliderMass: Float = 8.94e-3
  var sliderPosition: Float = .zero
  var sliderVelocity: Float = .zero
  
  func controlVoltageForce() -> Float {
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
    // Evaluate once with damping based on the engaged mass. If the surfaces
    // are in the kinetic regime of friction force, re-evaluate damping
    // based on the piezo mass.
    let engagedMass = System.piezoMass + System.sliderMass
    let piezoForce =
    controlVoltageForce() + dampingForce(engagedMass: engagedMass)
    
    // Sign convention for applied surface force: the direction that the piezo
    // pushes on the slider, to move the slider in that direction.
    //
    // Gravity may also be applied here: the sign of gravity equals the sign
    // gravity pulls on the slider. Static friction cancels gravity on the
    // slider and exerts all of it on the piezo. Instead of the piezo getting
    // displaced by the slider's gravity, it re-exerts the force onto the table.
    //
    // Gravity doesn't affect motion in the static regime. But it does increase
    // or reduce the applied surface force (depending on whether the signs are
    // constructive or destructive). In turn, the transition from static to
    // kinetic friction could happen more quickly or slowly.
    //
    // INCORRECT
    //
    // Gravity should be factored into the calculation. The combined gravity
    // of the piezo and slider (~100 mN) are exerted entirely in the piezo
    // material, straining it and causing a displacement via linear elasticity.
    // If this displacement caused a permanent voltage differential across the
    // piezo, we'd have an infinite source of energy that violates physics. So
    // pretend this doesn't do anything to voltage. Perhaps it induces charge
    // that dissipates into the circuit holding the plates exactly 0 V apart.
    // It is a capacitor charged to the associated voltage in pm/V, which gets
    // dissipated on contact.
    //
    // In the static regime, the combined gravity of the entire engaged mass
    // can factor into 'piezoForce'. Both the slider and piezo share the same
    // position. Gravitational acceleration is the same for both parts. All of
    // the gravitational energy gets stored in elastic strain energy of the
    // piezo. There is a disparity between actual position and position desired
    // by the control voltage. When the objects detach, some of this strain
    // energy (the portion due to the slider's gravity force) can be released,
    // making the piezo move upward more toward its equilibrium position.
    //
    // Due to the complexity of modeling gravity, we will not include it in
    // this analysis. We know that in prior literature, piezo step sizes are
    // skewed more toward the direction aligning with gravity. Gravity should
    // not be a deciding factor in whether stick-slip action works at all.
    let massRatio = System.sliderMass / (System.piezoMass + System.sliderMass)
    let piezoForceOnSlider = piezoForce * massRatio
    
    //
    static func frictionForce(appliedSurfaceForce: Float) -> Float {
      
    }
    
    let staticFrictionThreshold = System.normalForce * System.coefficientStatic
    print(appliedFriction, staticFrictionThreshold)
    
    piezoVelocity += timeStep * piezoForce / engagedMass
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

// Piecewise function where 1/3 of the trajectory is a parabola, 2/3 is a line,
// and the regions cross with no discontinuity in velocity.
func piecewiseFunction(x: Float) -> Float {
  if x < 1 {
    return x * x
  } else {
    return 1 + 2 * (x - 1)
  }
}

// MARK: - Script

var system = System()
for i in 1...1000 {
  // 500 μs hits a strange combination that perfectly cancels the vibrational
  // energy. 400 μs provides a better representation of typical responses. From
  // there, we increase the timespan a factor of 6 / 5 to 480 μs.
  let riseTimeSpan: Int = 480
  
  if i <= riseTimeSpan {
    let time = Float(i) * 1e-6
    
    #if false
    guard riseTimeSpan == 400 else {
      fatalError("Activate this case when rise time span is 400.")
    }
    let slewRate: Float = 850 / 400e-6
    let straightLineVoltage = time * slewRate
    system.controlVoltage = straightLineVoltage
    #else
    
    guard riseTimeSpan == 480 else {
      fatalError("Activate this case when rise time span is 480.")
    }
    let timeFraction = 3 * time / 480e-6
    let yFraction = piecewiseFunction(x: timeFraction)
    system.controlVoltage = yFraction / 5 * 850
    #endif
    
  } else {
    let time = Float(i - riseTimeSpan) * 1e-6
    let slewRate: Float = 10 / 1e-6
    
    #if false
    let straightLineVoltage = time * slewRate
    system.controlVoltage = max(0, 850 - straightLineVoltage)
    #else
    
    let endTime = 0.4 * 850 / slewRate
    var timeFraction = time / endTime
    timeFraction = max(0, 3 - timeFraction)
    let yFraction = piecewiseFunction(x: timeFraction)
    system.controlVoltage = yFraction / 5 * 850
    #endif
  }
  
  system.integrate(timeStep: 1e-6)
  
  if i % 1 == 0 {
    print("t = \(i) μs", terminator: " | ")
    print(Format.format(voltage: system.controlVoltage), "V", terminator: " | ")
    print(Format.format(position: system.piezoPosition), "nm", terminator: " | ")
    print(Format.format(position: system.sliderPosition), "nm", terminator: " | ")
    print(Format.format(velocity: system.piezoVelocity), "μm/s", terminator: " | ")
    print(Format.format(velocity: system.sliderVelocity), "μm/s")
  }
}
print("expected position:", system.controlVoltage * System.piezoConstant / 1e-9, "nm")

/*
 t = 991 μs |    0.0 V |   -13.9 nm |     0.0 nm |  -3216.1 μm/s |      0.0 μm/s
 t = 992 μs |    0.0 V |   -15.4 nm |     0.0 nm |  -1511.8 μm/s |      0.0 μm/s
 t = 993 μs |    0.0 V |   -15.0 nm |     0.0 nm |    377.0 μm/s |      0.0 μm/s
 t = 994 μs |    0.0 V |   -12.8 nm |     0.0 nm |   2219.1 μm/s |      0.0 μm/s
 t = 995 μs |    0.0 V |    -9.0 nm |     0.0 nm |   3788.6 μm/s |      0.0 μm/s
 t = 996 μs |    0.0 V |    -4.1 nm |     0.0 nm |   4893.5 μm/s |      0.0 μm/s
 t = 997 μs |    0.0 V |     1.3 nm |     0.0 nm |   5398.6 μm/s |      0.0 μm/s
 t = 998 μs |    0.0 V |     6.5 nm |     0.0 nm |   5242.1 μm/s |      0.0 μm/s
 t = 999 μs |    0.0 V |    10.9 nm |     0.0 nm |   4443.6 μm/s |      0.0 μm/s
 t = 1000 μs |    0.0 V |    14.0 nm |     0.0 nm |   3101.0 μm/s |      0.0 μm/s
 */
