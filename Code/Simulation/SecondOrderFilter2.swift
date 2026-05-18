import Foundation

// MARK: - Filters

let resonanceFrequency: Double = 8700
let Q: Double = 200
let dacResolution: Int = 1

struct BiquadFilterDescriptor {
  var resonanceFrequency: Double?
  var samplingFrequency: Double?
  var Q: Double?
}

// Using digital form of 2nd-order LPF with Q-factor to simulate the mechanical
// response to non-sinewave signals.
//
// https://www.ti.com/lit/an/slaa447/slaa447.pdf
// https://en.wikipedia.org/wiki/Digital_biquad_filter
struct BiquadFilter {
  var b: SIMD3<Double>
  var a: SIMD3<Double>
  
  var x2: Double = .zero
  var x1: Double = .zero
  var y2: Double = .zero
  var y1: Double = .zero
  
  init(descriptor: BiquadFilterDescriptor) {
    guard let resonanceFrequency = descriptor.resonanceFrequency,
          let samplingFrequency = descriptor.samplingFrequency,
          let Q = descriptor.Q else {
      fatalError("Descriptor was incomplete.")
    }
    
    let ω0 = 2 * Double.pi * resonanceFrequency / samplingFrequency
    let α = sin(ω0) / (2 * Q)
    
    let b0 = (1 - cos(ω0)) / 2
    let b1 = 1 - cos(ω0)
    let b2 = (1 - cos(ω0)) / 2
    let a0 = 1 + α
    let a1 = -2 * cos(ω0)
    let a2 = 1 - α
    
    self.b = SIMD3(b0, b1, b2)
    self.a = SIMD3(a0, a1, a2)
    
    // Normalize the coefficients.
    b /= a[0]
    a /= a[0]
    a[0] = 1
  }
  
  mutating func update(input: Double) -> Double {
    var output: Double = .zero
    output += b[0] * input + b[1] * x1 + b[2] * x2
    output -= a[1] * y1 + a[2] * y2
    
    // Shift delay lines.
    x2 = x1
    x1 = input
    y2 = y1
    y1 = output
    
    return output
  }
}

func createBiquadFilter() -> BiquadFilter {
  var filterDesc = BiquadFilterDescriptor()
  filterDesc.resonanceFrequency = resonanceFrequency
  filterDesc.samplingFrequency = 1_000_000
  filterDesc.Q = Q
  return BiquadFilter(descriptor: filterDesc)
}

// MARK: - Signal Generation

func createPeriod(targetFrequency: Float) -> Int {
  // Perhaps limit to multiples of 6 * dacResolution in the future.
  var output = 1e6 / targetFrequency
  output /= 12
  output.round(.toNearestOrEven)
  output *= 12
  return Int(output)
}

func triangleWave(phaseNormalized: Float) -> Float {
  if phaseNormalized < 0.5 {
    return 2 * phaseNormalized
  } else {
    return 2 * (1 - phaseNormalized)
  }
}

// TODO: Finish this investigation tomorrow.
// https://www.desmos.com/calculator/q7j7b9lqkx
func polynomialWaveOutskirts(progress: Float) -> Float {
  
}

func polynomialWave(phaseNormalized: Float) -> Float {
  fatalError("Not implemented.")
}

func sineWave(phaseNormalized: Float) -> Float {
  let cosinePart = cos(2 * Float.pi * phaseNormalized)
  return (1 - cosinePart) / 2
}

// MARK: - Simulation

let sinePeriod = createPeriod(targetFrequency: 300)
var biquadFilter = createBiquadFilter()
for t in 0..<sinePeriod {
  let dacApparentTime = t - (t % dacResolution)
  let phase = dacApparentTime % sinePeriod
  let phaseNormalized = Float(phase) / Float(sinePeriod)
  
  var signal: Double
  if dacApparentTime / sinePeriod < 3 {
    signal = Double(triangleWave(phaseNormalized: phaseNormalized))
  } else {
    signal = 0
  }
  
  let filtered = biquadFilter.update(input: signal)
  let error = filtered - signal
  
  func format(_ number: Double) -> String {
    var output = String(format: "%.5f", number)
    
    let exampleString = "-X.XXXXX"
    while output.count < exampleString.count {
      output = " " + output
    }
    return output
  }
  
  if t % 4 == 0 {
    print("t = \(t) μs", terminator: " | ")
    print("signal = \(format(signal))", terminator: " | ")
    print("biquad = \(format(filtered))", terminator: " | ")
    print("error = \(format(error))", terminator: " | ")
    print()
  }
}
