import Foundation

// MARK: - Filters

let resonanceFrequency: Float = 8700
let Q: Float = 200

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

func createFirstOrderFilter(cutoff: Float) -> FirstOrderFilter {
  var filterDesc = FirstOrderFilterDescriptor()
  filterDesc.cutoffFrequency = cutoff
  filterDesc.samplingFrequency = 1_000_000
  return FirstOrderFilter(descriptor: filterDesc)
}

// MARK: - Signal Generation

// Perfect impulse: 67 ms for +100 nm -> +/-10 pm (initial overshoot to 200 nm)
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

enum StepType {
  case immediate
  case firstOrderSmooth
  case secondOrderSmooth
}
let stepType: StepType = .firstOrderSmooth

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

// unit: μs
let dacResolution: Int = 12

// unit: μs
let riseTimes: [Int] = [
  100, 1000, 5000,
//  1000
]

// MARK: - Simulation

var trialResults: [SIMD3<Float>] = []
for trialID in riseTimes.indices {
  var biquadFilter = createBiquadFilter()
  var lowpassFilter38 = createFirstOrderFilter(cutoff: 3800)
  var lowpassFilter15 = createFirstOrderFilter(cutoff: 1500)
  
  let riseTime = riseTimes[trialID]
  
  func createSimulationTime() -> Int {
    var output: Int = .zero
    output += dacResolution
    if stepType != .immediate {
      output += riseTime
    }
    output += 2 * (1_000_000 / 1500)
    output += 3 * Int(1e6 / resonanceFrequency)
    return output
  }
  
  var maxAmplitudes: SIMD3<Float> = .zero
  for t in 0..<createSimulationTime() {
    let dacApparentTime = t - (t % dacResolution)
    let progress = Float(dacApparentTime) / Float(riseTime)
    let signal = 1 * smoothstep(progress: progress)
    
    let filtered = biquadFilter.update(input: signal)
    let filtered38 = lowpassFilter38.update(input: filtered)
    let filtered15 = lowpassFilter15.update(input: filtered)
    let amplitudes = SIMD3(filtered, filtered38, filtered15)
    maxAmplitudes.replace(
      with: amplitudes,
      where: amplitudes .> maxAmplitudes)
    
    func format(_ number: Float) -> String {
      var output = String(format: "%.5f", number)
      
      let exampleString = "-X.XXXXX"
      while output.count < exampleString.count {
        output = " " + output
      }
      return output
    }
    
    if t % 1 == 0 {
      print("t = \(t) μs", terminator: " | ")
      print("signal = \(format(signal))", terminator: " | ")
      print("biquad = \(format(filtered))", terminator: " | ")
      print("3.8k = \(format(filtered38))", terminator: " | ")
      print("1.5k = \(format(filtered15))", terminator: " | ")
      print()
    }
  }
  
  let overshootProportions = maxAmplitudes - 1
  trialResults.append(overshootProportions)
}

print()
for trialID in riseTimes.indices {
  let riseTime = riseTimes[trialID]
  let overshootProportions = trialResults[trialID]
  
  print(riseTime, terminator: ", ")
  print(overshootProportions[0], terminator: ", ")
  print(overshootProportions[1], terminator: ", ")
  print(overshootProportions[2], terminator: ", ")
  print()
}
