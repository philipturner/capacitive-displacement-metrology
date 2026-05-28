import Foundation

// MARK: - Filters

let resonanceFrequency: Double = 1470
let Q: Double = 18

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

enum StepType: CaseIterable {
  case immediate
  case linear
  case firstOrderSmooth
  case secondOrderSmooth
  case thirdOrderSmooth
  case fourthOrderSmooth // FP32 rounding error: 30 ppm
  // case fifthOrderSmooth // FP32 rounding error: 240 ppm
}

func smoothstep(
  stepType: StepType,
  progress: Float
) -> Float {
  if progress <= 0 {
    return 0
  } else if progress >= 1 {
    return 1
  } else {
    let x2 = progress * progress
    let x3 = x2 * progress
    let x4 = x3 * progress
    let x5 = x4 * progress
    let x6 = x5 * progress
    let x7 = x6 * progress
    let x8 = x7 * progress
    let x9 = x8 * progress
    // let x10 = x9 * progress
    // let x11 = x10 * progress
    
    switch stepType {
    case .immediate:
      return 1
    case .linear:
      return progress
    case .firstOrderSmooth:
      return 3 * x2 - 2 * x3
    case .secondOrderSmooth:
      return 6 * x5 - 15 * x4 + 10 * x3
    case .thirdOrderSmooth:
      return -20 * x7 + 70 * x6 - 84 * x5 + 35 * x4
    case .fourthOrderSmooth:
      return 70 * x9 - 315 * x8 + 540 * x7 - 420 * x6 + 126 * x5
      // case .fifthOrderSmooth:
      //   return -252 * x11 + 1386 * x10 - 3080 * x9 + 3465 * x8 - 1980 * x7 + 462 * x6
    }
  }
}

let stepTypes: [StepType] = [
  .immediate,
  .linear,
  .thirdOrderSmooth,
]

for stepType in stepTypes {
  func createRiseTimes() -> [Int] {
    if stepType == .immediate {
      return [300]
    }
    
    var output: [Int] = []
    for i in 0...40 {
      let decades = Float(i) / 20
      
      var value = pow(10, decades)
      value *= 300
      value.round(.toNearestOrEven)
      output.append(Int(value))
    }
    return output
  }
  
  // unit: μs
  let dacResolution: Int = 12 // limiter for infinitely smooth curves
  
  // unit: μs
  let riseTimes: [Int] = createRiseTimes()
  
  let amplitudeMultiplier: Double = 1
  
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
    
    let riseTime = riseTimes[trialID]
    func createSimulationTime() -> Int {
      var settlingTimeReciprocalE = 1e6 / resonanceFrequency * Q / Double.pi
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
      let progress = Float(dacApparentTime) / Float(riseTime)
      let smoothedProgress = smoothstep(
        stepType: stepType,
        progress: progress)
      let signal = amplitudeMultiplier * Double(smoothedProgress)
      
      let filtered = biquadFilter.update(input: signal)
      
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
        print()
      }
#endif
      
      let error = SIMD3(filtered, filtered, filtered) - amplitudeMultiplier
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
    
    func printVector(_ time: SIMD3<UInt64>) {
      func format(_ microseconds: UInt64) -> String {
        let milliseconds = Double(microseconds) / 1000
        return String(format: "%.3f", milliseconds)
      }
      
      print(format(time[0]), terminator: ", ")
    }
    printVector(results.settlingTime2Decade)
    printVector(results.settlingTime3Decade)
    printVector(results.settlingTime4Decade)
    
    print()
  }
}
