import Foundation

// Filter parameters
let resonanceFrequency: Float = 8700 // Hz
let Q: Float = 200
let lowpassCutoff: Float = 1500 // Hz

// Signal parameters
let dacResolution: Int = 12 // μs
let signalAmplitude: Float = 100
let riseTime: Int = 100 // μs

enum StepType {
  case immediate
  case firstOrderSmooth
  case secondOrderSmooth
}
let stepType: StepType = .immediate

// MARK: - Filters

struct BiquadFilterDescriptor {
  var resonanceFrequency: Float?
  var samplingFrequency: Float?
  var Q: Float?
}

// Using digital form of 2nd-order LPF with Q-factor to simulate the mechanical
// response to non-sinewave signals.
//
// https://www.ti.com/lit/an/slaa447/slaa447.pdf
// https://en.wikipedia.org/wiki/Digital_biquad_filter
struct BiquadFilter {
  var b: SIMD3<Float>
  var a: SIMD3<Float>
  
  var x2: Float = .zero
  var x1: Float = .zero
  var y2: Float = .zero
  var y1: Float = .zero
  
  init(descriptor: BiquadFilterDescriptor) {
    guard let resonanceFrequency = descriptor.resonanceFrequency,
          let samplingFrequency = descriptor.samplingFrequency,
          let Q = descriptor.Q else {
      fatalError("Descriptor was incomplete.")
    }
    
    let ω0 = 2 * Float.pi * resonanceFrequency / samplingFrequency
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
  
  mutating func update(input: Float) -> Float {
    var output: Float = .zero
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

struct FirstOrderFilterDescriptor {
  var cutoffFrequency: Float?
  var samplingFrequency: Float?
}

struct FirstOrderFilter {
  var a: Float
  
  var y1: Float = .zero
  
  init(descriptor: FirstOrderFilterDescriptor) {
    guard let cutoffFrequency = descriptor.cutoffFrequency,
          let samplingFrequency = descriptor.samplingFrequency else {
      fatalError("Descriptor was incomplete.")
    }
    
    let sampleTime = 1 / samplingFrequency
    let timeConstant = 1 / (2 * Float.pi * cutoffFrequency)
    self.a = sampleTime / (timeConstant + sampleTime)
  }
  
  mutating func update(input: Float) -> Float {
    var output: Float = .zero
    output += a * input
    output += (1 - a) * y1
    
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
var biquadFilter = createBiquadFilter()

func createFirstOrderFilter() -> FirstOrderFilter {
  var filterDesc = FirstOrderFilterDescriptor()
  filterDesc.cutoffFrequency  = lowpassCutoff
  filterDesc.samplingFrequency = 1_000_000
  return FirstOrderFilter(descriptor: filterDesc)
}
var firstOrderFilter = createFirstOrderFilter()

// Perfect impulse: 67 ms for +100 nm -> +/-10 pm (initial overshoot to 200 nm)
// Sine waves have +/-100 nm amplitude
//
// Smooth DAC waveform
// Smoothstep, 1st order: 61 ms @ 100 μs (initial overshoot to 142 nm)
// Smoothstep, 1st order: 25 ms @ 1000 μs (initial overshoot to 232 pm)
// Smoothstep, 1st order: 13 ms @ 2000 μs (initial overshoot to 30 pm)
// Smoothstep, 1st order: 14 ms @ 3000 μs (initial overshoot to 40 pm)
// Smoothstep, 1st order: 8 ms @ 4000 μs (initial overshoot to 18 pm)
// Smoothstep, 1st order: 5 ms @ 5000 μs (initial overshoot to 5 pm)
// Smoothstep, 2nd order: 100 μs -> initial overshoot to 156 nm
// Smoothstep, 2nd order: 1000 μs -> initial overshoot to 53 pm
// Smoothstep, 2nd order: 2000 μs -> initial overshoot to 9 pm
// Smoothstep, 2nd order: 3000 μs -> initial overshoot to 5 pm
// Smoothstep, 2nd order: 4000 μs -> initial overshoot to 5 pm
// Smoothstep, 2nd order: 5000 μs -> initial overshoot to 5 pm
//
// Steppy DAC waveform (12 μs)
// Smoothstep, 1st order: 100 μs -> initial overshoot to 141 nm
// Smoothstep, 1st order: 1000 μs -> initial overshoot to
// Smoothstep, 1st order: 2000 μs -> initial overshoot to
// Smoothstep, 1st order: 3000 μs -> initial overshoot to
// Smoothstep, 1st order: 4000 μs -> initial overshoot to
// Smoothstep, 1st order: 5000 μs -> initial overshoot to
// Smoothstep, 2nd order: 100 μs -> initial overshoot to
// Smoothstep, 2nd order: 1000 μs -> initial overshoot to
// Smoothstep, 2nd order: 2000 μs -> initial overshoot to
// Smoothstep, 2nd order: 3000 μs -> initial overshoot to
// Smoothstep, 2nd order: 4000 μs -> initial overshoot to
// Smoothstep, 2nd order: 5000 μs -> initial overshoot to

func smoothstep(progress: Float) -> Float {
  if progress <= 0 {
    return 0
  } else if progress >= 1 {
    return 1
  } else {
    let x2 = progress * progress
    let x3 = x2 * progress
    let x4 = x3 * progress
    let x5 = x4 * progress
    
    switch stepType {
    case .immediate:
      return 1
    case .firstOrderSmooth:
      return 3 * x2 - 2 * x3
    case .secondOrderSmooth:
      return 6 * x5 - 15 * x4 + 10 * x3
    }
  }
}

// MARK: - Simulation

for t in 0..<1_000 {
  let steppedTime = t - (t % dacResolution)
  let progress = Float(steppedTime) / Float(riseTime)
  let signal = signalAmplitude * smoothstep(progress: progress)
  let filtered = biquadFilter.update(input: signal)
  let filtered2 = firstOrderFilter.update(input: filtered)
  
  func format(_ number: Float) -> String {
    var output = String(format: "%.3f", number)
    
    let exampleString = "-XXX.XXX"
    while output.count < exampleString.count {
      output = " " + output
    }
    return output
  }
  
  if t % 1 == 0 {
    print("t = \(t) μs", terminator: " | ")
    print("signal = \(format(signal))", terminator: " | ")
    print("filtered = \(format(filtered))", terminator: " | ")
    print("filtered2 = \(format(filtered2))", terminator: " | ")
    print()
  }
}
