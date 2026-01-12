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
  
  static var gravityAcceleration: Float = 0.0
  static var normalForce: Float = 2.22
  static var coefficientStatic: Float = 0.5
  static var coefficientKinetic: Float = 0.4
  static let kineticVelocityThreshold: Float = 1e-6
  static var maxSlewRate: Float = 10e6
  
  static let piezoConstant: Float = 80e-12 * 6
  static let piezoMass: Float = 3 * 1.02e-3
  var piezoPosition: Float = .zero
  static let piezoQualityFactor: Float = 1000
  static let piezoStiffness: Float = 0.644e9
  var piezoVelocity: Float = .zero
  
  static let sliderMass: Float = 8.94e-3
  var sliderPosition: Float = .zero
  var sliderVelocity: Float = .zero
  
  var controlVoltageForce: Float {
    var targetDisplacement = System.piezoConstant * controlVoltage
    targetDisplacement -= piezoPosition
    return System.piezoStiffness * targetDisplacement
  }
  
  func dampingForce(engagedMass: Float) -> Float {
    var dampingCoefficient = 1 / System.piezoQualityFactor
    dampingCoefficient *= (System.piezoStiffness * engagedMass).squareRoot()
    return -dampingCoefficient * piezoVelocity
  }
  
  var mode: FrictionMode {
    let velocityDelta = sliderVelocity - piezoVelocity
    if velocityDelta.magnitude > Self.kineticVelocityThreshold {
      return .kinetic
    }
    
    let appliedSurfaceForce = controlForceOnPiezo(mode: .static)
    let staticThreshold = System.normalForce * System.coefficientStatic
    if appliedSurfaceForce.magnitude > staticThreshold {
      return .kinetic
    } else {
      return .static
    }
  }
  
  func controlForceOnPiezo(mode: FrictionMode) -> Float {
    if mode == .static {
      let engagedMass = System.piezoMass + System.sliderMass
      let piezoForce = controlVoltageForce + dampingForce(engagedMass: engagedMass)
      let massRatio = System.piezoMass / (System.piezoMass + System.sliderMass)
      return piezoForce * massRatio
    } else {
      let engagedMass = System.piezoMass
      let piezoForce = controlVoltageForce + dampingForce(engagedMass: engagedMass)
      return piezoForce
    }
  }
  
  func controlForceOnSlider(mode: FrictionMode) -> Float {
    if mode == .static {
      let engagedMass = System.piezoMass + System.sliderMass
      let piezoForce = controlVoltageForce + dampingForce(engagedMass: engagedMass)
      let massRatio = System.sliderMass / (System.piezoMass + System.sliderMass)
      return piezoForce * massRatio
    } else {
      return 0
    }
  }
}

extension System {
  mutating func integrate(timeStep: Float) {
    var mode: FrictionMode = self.mode
    if mode == .static {
      sliderVelocity = piezoVelocity
    }
    
    let controlForceOnPiezo = self.controlForceOnPiezo(mode: mode)
    let controlForceOnSlider = self.controlForceOnSlider(mode: mode)
    piezoVelocity += timeStep * controlForceOnPiezo / System.piezoMass
    sliderVelocity += timeStep * controlForceOnSlider / System.sliderMass
    
    // Just add gravity
    // F = ma
    // v += t * F / m
    // v += t * a
    piezoVelocity += timeStep * System.gravityAcceleration
    sliderVelocity += timeStep * System.gravityAcceleration
    
    var kineticForceOnPiezo: Float = .zero
    var kineticForceOnSlider: Float = .zero
    if mode == .kinetic {
      // WARNING: Do not mutate the instance of 'System' in between calls to
      // this function.
      func kineticForce() -> Float {
        if piezoVelocity < sliderVelocity {
          return System.normalForce * System.coefficientKinetic
        } else if piezoVelocity > sliderVelocity {
          return -System.normalForce * System.coefficientKinetic
        } else {
          return 0
        }
      }
      var safeKineticForce = kineticForce()
      
      let deltaBefore = sliderVelocity - piezoVelocity
      let piezoTemp = piezoVelocity + timeStep * safeKineticForce / System.piezoMass
      let sliderTemp = sliderVelocity - timeStep * safeKineticForce / System.sliderMass
      let deltaAfter = sliderTemp - piezoTemp
      
      if deltaBefore * deltaAfter < 0 {
        // The relative velocity is about to invert.
        let progressBefore = deltaBefore.magnitude
        let progressAfter = deltaAfter.magnitude
        safeKineticForce *= progressBefore / (progressBefore + progressAfter)
      }
      
      kineticForceOnPiezo = safeKineticForce
      kineticForceOnSlider = -safeKineticForce
    }
    piezoVelocity += timeStep * kineticForceOnPiezo / System.piezoMass
    sliderVelocity += timeStep * kineticForceOnSlider / System.sliderMass
    
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
  
  static func format(positionHighRes: Float) -> String {
    var output = String(format: "%.3f", positionHighRes / 1e-9)
    while output.count < "-1000.000".count {
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

let terminator: String = ", "

func runTrial() {
  var system = System()
  for i in 1...100_000 {
    // Rise time for the slow-moving part of the waveform, in microseconds.
    let riseTimeSpan: Int = 480
    
    if i <= riseTimeSpan {
      let time = Float(i) * 1e-6
      
      guard riseTimeSpan == 480 else {
        fatalError("Activate this case when rise time span is 480.")
      }
      let timeFraction = 3 * time / 480e-6
      let yFraction = piecewiseFunction(x: timeFraction)
      system.controlVoltage = yFraction / 5 * 850
      
    } else {
      let time = Float(i - riseTimeSpan) * 1e-6
      let slewRate: Float = System.maxSlewRate
      
      let endTime = 0.4 * 850 / slewRate
      var timeFraction = time / endTime
      timeFraction = max(0, 3 - timeFraction)
      let yFraction = piecewiseFunction(x: timeFraction)
      system.controlVoltage = yFraction / 5 * 850
    }
    
    #if false
    let mode = system.mode
    #endif
    system.integrate(timeStep: 1e-6)
    
    #if false
    if i % 1 == 0 {
      print("t = \(i) μs", terminator: " | ")
      print(Format.format(voltage: system.controlVoltage), "V", terminator: " | ")
      print(Format.format(positionHighRes: system.piezoPosition), "nm", terminator: " | ")
      print(Format.format(positionHighRes: system.sliderPosition), "nm", terminator: " | ")
      print(Format.format(velocity: system.piezoVelocity), "μm/s", terminator: " | ")
      print(Format.format(velocity: system.sliderVelocity - system.piezoVelocity), "μm/s", terminator: " | ")
      print(mode)
    }
    #endif
  }
  
  var positionToPrint = system.sliderPosition
  if positionToPrint.magnitude > 2e-6 {
    if positionToPrint < 0 {
      positionToPrint = -Float.infinity
    } else {
      positionToPrint = Float.infinity
    }
  }
  print(Format.format(position: positionToPrint), terminator: terminator)
}

let maxSlewRateList: [Float] = [3e6, 5e6, 10e6, 20e6, 30e6]
let frictionCoefficientsList: [SIMD2<Float>] = [
  SIMD2<Float>(1.0, 0.4) * 0.1,
  SIMD2<Float>(1.0, 0.4) * 0.3,
  SIMD2<Float>(1.0, 0.4) * 0.5,
  SIMD2<Float>(1.0, 0.4) * 0.7,
  SIMD2<Float>(1.0, 0.4) * 0.9,
  
  SIMD2<Float>(1.0, 0.8) * 0.1,
  SIMD2<Float>(1.0, 0.8) * 0.3,
  SIMD2<Float>(1.0, 0.8) * 0.5,
  SIMD2<Float>(1.0, 0.8) * 0.7,
  SIMD2<Float>(1.0, 0.8) * 0.9,
]
let gravityList: [Float] = [-9.8, 0.0, 9.8]

for maxSlewRate in maxSlewRateList {
  for frictionCoefficients in frictionCoefficientsList {
    System.normalForce = 0.1
    System.coefficientStatic = frictionCoefficients[0]
    System.coefficientKinetic = frictionCoefficients[1]
    System.maxSlewRate = maxSlewRate
    
    print(String(format: "%.1f", System.normalForce), terminator: terminator)
    print(String(format: "%.2f", System.coefficientStatic), terminator: terminator)
    print(String(format: "%.2f", System.coefficientKinetic), terminator: terminator)
    print(System.maxSlewRate, terminator: terminator)
    
    for gravity in gravityList {
      System.gravityAcceleration = gravity
      runTrial()
    }
    print()
  }
  print()
}
