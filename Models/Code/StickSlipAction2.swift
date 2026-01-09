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

enum FrictionMode {
  case kinetic
  case `static`
}

struct System {
  // Allowed range: -425 V to 425 V
  // For simplicity, 0 V to 850 V is also permitted
  var controlVoltage: Float = .zero
  
  static let normalForce: Float = 2.22
  static let coefficientStatic: Float = 0.5
  static let coefficientKinetic: Float = 0.4
  static let kineticVelocityThreshold: Float = 100e-6
  
  static let piezoConstant: Float = 80e-12 * 6
  static let piezoMass: Float = 3 * 1.02e-3
  var piezoPosition: Float = .zero
  static let piezoQualityFactor: Float = 1000
  static let piezoStiffness: Float = 1.47e9
  var piezoVelocity: Float = .zero
  
  static let sliderMass: Float = 8.94e-3
  var sliderPosition: Float = .zero
  var sliderVelocity: Float = .zero
  
  var controlVoltageForce: Float {
    let expectedPosition = controlVoltage * System.piezoConstant
    let deltaX = piezoPosition - expectedPosition
    return -System.piezoStiffness * deltaX
  }
  
  func dampingForce(engagedMass: Float) -> Float {
    var dampingCoefficient = 1 / System.piezoQualityFactor
    dampingCoefficient *= (System.piezoStiffness * engagedMass).squareRoot()
    return -dampingCoefficient * piezoVelocity
  }
}

extension System {
  var mode: FrictionMode {
    let velocityDelta = sliderVelocity - piezoVelocity
    if velocityDelta.magnitude > Self.kineticVelocityThreshold {
      // One remaining bug: system must snap the slider's velocity to exactly
      // the piezo's velocity when it becomes static again
      return .kinetic
    }
    
    let appliedSurfaceForce = forceOnSlider(mode: .static)
    let staticThreshold = System.normalForce * System.coefficientStatic
    if appliedSurfaceForce.magnitude > staticThreshold {
      return .kinetic
    } else {
      return .static
    }
  }
  
  static var kineticForceMagnitude: Float {
    System.normalForce * System.coefficientKinetic
  }
  
  func forceOnPiezo(mode: FrictionMode) -> Float {
    if mode == .static {
      let engagedMass = System.piezoMass + System.sliderMass
      let piezoForce = controlVoltageForce + dampingForce(engagedMass: engagedMass)
      let massRatio = System.piezoMass / (System.piezoMass + System.sliderMass)
      return piezoForce * massRatio
    } else {
      let engagedMass = System.piezoMass
      let piezoForce = controlVoltageForce + dampingForce(engagedMass: engagedMass)
      
      func kineticForce() -> Float {
        if sliderVelocity > piezoVelocity {
          return Self.kineticForceMagnitude
        } else {
          return -Self.kineticForceMagnitude
        }
      }
      return piezoForce + kineticForce()
    }
  }
  
  func forceOnSlider(mode: FrictionMode) -> Float {
    if mode == .static {
      let engagedMass = System.piezoMass + System.sliderMass
      let piezoForce = controlVoltageForce + dampingForce(engagedMass: engagedMass)
      let massRatio = System.sliderMass / (System.piezoMass + System.sliderMass)
      return piezoForce * massRatio
    } else {
      func kineticForce() -> Float {
        if piezoVelocity > sliderVelocity {
          return Self.kineticForceMagnitude
        } else {
          return -Self.kineticForceMagnitude
        }
      }
      return kineticForce()
    }
  }
  
  mutating func integrate(timeStep: Float) {
    let mode: FrictionMode = self.mode
    let forceOnPiezo = self.forceOnPiezo(mode: mode)
    let forceOnSlider = self.forceOnSlider(mode: mode)
    print(Format.format(force: forceOnPiezo), "N", terminator: " | ")
    print(Format.format(force: forceOnSlider), "N", terminator: " | ")
    
    piezoVelocity += timeStep * forceOnPiezo / System.piezoMass
    sliderVelocity += timeStep * forceOnSlider / System.sliderMass
    
    piezoPosition += timeStep * piezoVelocity
    sliderPosition += timeStep * sliderVelocity
  }
}

struct Format {
  static func format(force: Float) -> String {
    var output = String(format: "%.3f", force)
    while output.count < "-10.000".count {
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
  
  static func format(voltage: Float) -> String {
    var output = String(format: "%.1f", voltage)
    while output.count < "-425.0".count {
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
  
  let mode = system.mode
  system.integrate(timeStep: 1e-6)
  
  if i % 1 == 0 {
    print("t = \(i) μs", terminator: " | ")
    print(Format.format(voltage: system.controlVoltage), "V", terminator: " | ")
    print(Format.format(position: system.piezoPosition), "nm", terminator: " | ")
    print(Format.format(position: system.sliderPosition), "nm", terminator: " | ")
    print(Format.format(velocity: system.piezoVelocity), "μm/s", terminator: " | ")
    print(Format.format(velocity: system.sliderVelocity), "μm/s", terminator: " | ")
    print(mode)
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
