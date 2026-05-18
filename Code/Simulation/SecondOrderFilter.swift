import Foundation

let resonanceFrequency: Float = 8700
let Q: Float = 200

let signalAmplitude: Float = 100
let signalFrequency: Float = 1000
let riseTime: Int = 100

// Using digital form of 2nd-order LPF with Q-factor to simulate the mechanical
// response to non-sinewave signals.
//
// https://www.ti.com/lit/an/slaa447/slaa447.pdf
// https://en.wikipedia.org/wiki/Digital_biquad_filter

struct BiquadFilterDescriptor {
  var resonanceFrequency: Float?
  var samplingFrequency: Float?
  var Q: Float?
}

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

var filterDesc = BiquadFilterDescriptor()
filterDesc.resonanceFrequency = resonanceFrequency
filterDesc.samplingFrequency = 1_000_000
filterDesc.Q = Q
var filter = BiquadFilter(descriptor: filterDesc)

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
// 100 Hz sine wave
// 1000 Hz sine wave
// 8700 Hz sine wave
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
// 100 Hz sine wave
// 1000 Hz sine wave
// 8700 Hz sine wave
//
func smoothstep(progress: Float) -> Float {
  if progress <= 0 {
    return 0
  } else if progress >= 1 {
    return 1
  } else {
    let x2 = progress * progress
    let x3 = x2 * progress
    let x4 = x3 * progress
    let x5 = x3 * progress * progress
    #if true
    return 3 * x2 - 2 * x3
    #else
    return 6 * x5 - 15 * x4 + 10 * x3
    #endif
  }
}

for t in 0..<(riseTime + 230) {
  /*
  let signalPeriod = Int(Float(1e6) / signalFrequency)
  let phase = t % signalPeriod
  
  let phaseNormalized = Float(phase) / Float(signalPeriod)
  let signal = signalAmplitude * sin(2 * Float.pi * phaseNormalized)
   */
  
  let progress = Float(t - (t % 12)) / Float(riseTime)
  let signal = signalAmplitude * smoothstep(progress: progress)
  let filteredSignal = filter.update(input: signal)
  
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
    print("filtered = \(format(filteredSignal))", terminator: " | ")
    print()
  }
}
