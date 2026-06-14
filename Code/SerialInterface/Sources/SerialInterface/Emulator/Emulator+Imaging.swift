import Foundation

extension Emulator {
  // Returns the current relative to the setpoint.
  static func normalizedCurrent(position: SIMD2<Float>) -> Float {
    // min: -0.5
    // avg: 0.0
    // max: 1.0
    func getCorrugationAmplitude() -> Float {
      let atomSpacing: Float = 0.246 // units: nm
      let x = position[0] / atomSpacing
      let y = position[1] / atomSpacing
      
      var phases: SIMD3<Float> = .zero
      phases[0] = x
      phases[1] = -0.5 * x + (Float(3).squareRoot() / 2) * y
      phases[2] = -0.5 * x - (Float(3).squareRoot() / 2) * y
      
      var corrugationAmplitude: Float = .zero
      for laneID in 0..<3 {
        var phaseNormalized = phases[laneID]
        phaseNormalized -= phaseNormalized.rounded(.down)
        corrugationAmplitude += cos(2 * Float.pi * phaseNormalized)
      }
      corrugationAmplitude /= 3
      
      return corrugationAmplitude
    }
    
    func randomGaussian() -> Float {
      var u1: Float = .zero
      while u1 < 0.001 {
        u1 = Float.random(in: 0..<1)
      }
      let u2 = Float.random(in: 0..<1)
      
      // Box-Muller Transform formula
      return sqrt(-2.0 * log(u1)) * cos(2.0 * Float.pi * u2)
    }
    
    var output: Float = 1
    output += 0.2 * getCorrugationAmplitude()
    output += 0.03 * randomGaussian()
    return output
  }
}
