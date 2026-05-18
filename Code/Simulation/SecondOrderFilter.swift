import Foundation

// MARK: - Filters

let resonanceFrequency: Double = 8700
let Q: Double = 200

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

struct FirstOrderFilterDescriptor {
  var cutoffFrequency: Double?
  var samplingFrequency: Double?
}

struct FirstOrderFilter {
  var a: Double
  
  var y1: Double = .zero
  
  init(descriptor: FirstOrderFilterDescriptor) {
    guard let cutoffFrequency = descriptor.cutoffFrequency,
          let samplingFrequency = descriptor.samplingFrequency else {
      fatalError("Descriptor was incomplete.")
    }
    
    let sampleTime = 1 / samplingFrequency
    let timeConstant = 1 / (2 * Double.pi * cutoffFrequency)
    self.a = sampleTime / (timeConstant + sampleTime)
  }
  
  mutating func update(input: Double) -> Double {
    var output: Double = .zero
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

func createFirstOrderFilter(cutoff: Double) -> FirstOrderFilter {
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

func smoothstep(progress: Double) -> Double {
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
// TODO: Auto-generate a smooth logarithmic spectrum from 30 μs to 30 ms
let riseTimes: [Int] = [
  100, //1000, 5000,
]

let amplitudeMultiplier: Double = 0.3

// MARK: - Simulation

struct TrialResults {
  var overshoot: SIMD3<Double> = .zero
  var settlingTime2Decade = SIMD3<UInt64>(repeating: .max) // μs
  var settlingTime3Decade = SIMD3<UInt64>(repeating: .max) // μs
  var settlingTime4Decade = SIMD3<UInt64>(repeating: .max) // μs
}

var trialResults: [TrialResults] = []
for trialID in riseTimes.indices {
  var biquadFilter = createBiquadFilter()
  var lowpassFilter38 = createFirstOrderFilter(cutoff: 3800)
  var lowpassFilter15 = createFirstOrderFilter(cutoff: 1500)
  
  let riseTime = riseTimes[trialID]
  func createSimulationTime() -> Int {
    var settlingTimeReciprocalE = 1e6 / resonanceFrequency * Q / Double.pi
    settlingTimeReciprocalE += (1e6 / 1500) / (2 * Double.pi)
    let settlingTimeSixDecades = settlingTimeReciprocalE * 13.82
    
    var output = Int(settlingTimeSixDecades)
    if stepType != .immediate {
      output += riseTime
    }
    return output
  }

  // Approximate time span of one resonant vibration, in μs.
  let resonancePeriod = Int(1e6 / resonanceFrequency)
  let historyLength: Int = 3 * resonancePeriod
  var history = [SIMD3<Double>](
    repeating: .zero, count: historyLength)
  
  var results = TrialResults()
  for t in 0..<createSimulationTime() {
    let dacApparentTime = t - (t % dacResolution)
    let progress = Double(dacApparentTime) / Double(riseTime)
    let signal = amplitudeMultiplier * smoothstep(progress: progress)
    
    let filtered = biquadFilter.update(input: signal)
    let filtered38 = lowpassFilter38.update(input: filtered)
    let filtered15 = lowpassFilter15.update(input: filtered)
    
    #if false
    func format(_ number: Double) -> String {
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
    #endif
    
    let error = SIMD3(filtered, filtered38, filtered15) - amplitudeMultiplier
    history[t % historyLength] = error
    results.overshoot.replace(
      with: error, where: error .> results.overshoot)
    
    if t >= historyLength, t % resonancePeriod == 0 {
      func createMinimumTime(threshold: Double) -> SIMD3<UInt64> {
        var output = SIMD3<UInt64>(
          repeating: UInt64(t - historyLength))
        let failure = SIMD3<UInt64>(repeating: .max)
        
        for error in history {
          output.replace(
            with: failure, where: error .> threshold)
          output.replace(
            with: failure, where: error .< -threshold)
        }
        return output
      }
      
      let time2Decade = createMinimumTime(threshold: amplitudeMultiplier * 1e-2)
      let time3Decade = createMinimumTime(threshold: amplitudeMultiplier * 1e-3)
      let time4Decade = createMinimumTime(threshold: amplitudeMultiplier * 1e-4)
      results.settlingTime2Decade.replace(
        with: time2Decade, where: time2Decade .< results.settlingTime2Decade)
      results.settlingTime3Decade.replace(
        with: time3Decade, where: time3Decade .< results.settlingTime3Decade)
      results.settlingTime4Decade.replace(
        with: time4Decade, where: time4Decade .< results.settlingTime4Decade)
    }
  }
  
  trialResults.append(results)
}

print()
for trialID in riseTimes.indices {
  let riseTime = riseTimes[trialID]
  let results = trialResults[trialID]
  
  print(riseTime, terminator: ", ")
  print(Float(results.overshoot[0]), terminator: ", ")
  print(Float(results.overshoot[1]), terminator: ", ")
  print(Float(results.overshoot[2]), terminator: ", ")
  
  func printVector(_ time: SIMD3<UInt64>) {
    func format(_ microseconds: UInt64) -> String {
      let milliseconds = Double(microseconds) / 1000
      return String(format: "%.3f", milliseconds)
    }
    
    print(format(time[0]), terminator: ", ")
    print(format(time[1]), terminator: ", ")
    print(format(time[2]), terminator: ", ")
  }
  printVector(results.settlingTime4Decade)
  
  print()
}
