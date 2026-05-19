import Foundation

// MARK: - Filters

let resonanceFrequency: Double = 8700
let Q: Double = 200
let dacResolution: Int = 12

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

// Polynomial curve equations:
// https://www.desmos.com/calculator/q7j7b9lqkx

// x = 0   -> y = 0.000, y' = 0
// x = 0.5 -> y = 0.068
// x = 1   -> y = 0.500, y' = 1
func polynomialWaveOutskirt(x: Float) -> Float {
  let x2 = x * x
  let x3 = x2 * x
  let x5 = x2 * x2 * x
  
  var output = -2.5 * x3 + 10 * x2 - 14 * x + 7
  output *= x5
  return output
}

// x = 0   -> y = 0.500, y' = -1
// x = 0.5 -> y = 0.137, y' = 0
// x = 1   -> y = 0.500, y' = 1
func polynomialWaveBend(x: Float) -> Float {
  let x2 = x * x
  let x3 = x2 * x
  let x5 = x2 * x2 * x
  
  var output = -2.5 * x3 + 10 * x2 - 14 * x + 7
  output *= 2
  output *= x5
  output += -x + 0.5
  return output
}

// x = 0.0 to 0.5 -> bend, y: -1.363 to -1.0
// x = 0.5 to 2.5 -> straight line, y: -1.0 to 1.0
// x = 2.5 to 3.5 -> bend, y: 1.0 to 1.363
// x = 3.5 to 5.5 -> straight line, y: 1.0 to -1.0
// x = 5.5 to 6.0 -> bend, y: -1.0 to -1.363
//
// with outskirts:
// x = 0.0 to 1.0 -> flat, y: 0.0
// x = 1.0 to 2.0 -> outskirt, y: 0.0 to 0.5
// x = 4.0 to 5.0 -> outskirt, y: 0.5 to 0.0
// x = 5.0 to 6.0 -> flat, y: 0.0
func polynomialWave(
  x: Float,
  hasStartOutskirt: Bool,
  hasEndOutskirt: Bool
) -> Float {
  if x < 0.0 || x > 6.0 {
    fatalError("x was out of range: \(x)")
  }
  
  if hasStartOutskirt {
    if x < 1.0 {
      return 0
    } else if x < 2.0 {
      return polynomialWaveOutskirt(x: x - 1.0)
    }
  }
  if hasEndOutskirt {
    if x > 5.0 {
      return 0
    } else if x > 4.0 {
      return polynomialWaveOutskirt(x: 5.0 - x)
    }
  }
  
  if x < 0.5 {
    return polynomialWaveBend(x: x + 0.5) - 1.5
  } else if x < 2.5 {
    return x - 1.5
  } else if x < 3.5 {
    return 1.5 - polynomialWaveBend(x: x - 2.5)
  } else if x < 5.5 {
    return 4.5 - x
  } else {
    return polynomialWaveBend(x: x - 5.5) - 1.5
  }
}

func sineWave(phaseNormalized: Float) -> Float {
  let cosinePart = cos(2 * Float.pi * phaseNormalized)
  return (1 - cosinePart) / 2
}

func createPolynomialWaveAmplitude() -> Float {
  var output: Float = .zero
  output += -5 / 256
  output += 20 / 128
  output += -28 / 64
  output += 14 / 32
  
  return 1.5 - output
}
let polynomialWaveAmplitude = createPolynomialWaveAmplitude()

enum WaveType {
  case triangle
  case polynomial(includeOutskirts: Bool)
  case sine
}

// MARK: - Simulation

// dacResolution = 1
// 299.8, 0.030572401,  0.10237548,    0.09177834,    0.088686444,   0.088685155,
// 299.8, 0.0033599513, 0.0027202333,  0.001727616,   0.0017382766,  0.0017383934,
// 299.8, 0.0018198132, 0.001905912,   0.00018583612, 0.0017953466,  0.0018012689,
// 299.8, 0.0011890095, 0.00097353716, 0.0005939361,  0.00059436227, 0.00059435616,

// dacResolution = 12
// 299.8, 0.03423165,   0.105896935,  0.09342409,    0.09052499,    0.090524025,
// 299.8, 0.005575105,  0.0049367407, 0.0017042201,  0.0017057727,  0.0017055453,
// 299.8, 0.0039054018, 0.004009853,  0.00018291663, 0.0017618802,  0.0017685278,
// 299.8, 0.0058272784, 0.005625855,  0.00058265077, 0.00058323867, 0.0005831024,

let waveType: WaveType = .sine

let sinePeriod = createPeriod(targetFrequency: 300)
let targetDuration: Int = 70_000
let waveCount = max(10, targetDuration / sinePeriod)
let duration = sinePeriod * waveCount + sinePeriod + 1_000

var biquadFilter = createBiquadFilter()

struct TrialResults {
  var errorStart: Double = .zero
  var errorAC: Double = .zero
  var errorEnd: Double = .zero
  var maximumAC: Double = -.greatestFiniteMagnitude
  var minimumAC: Double = .greatestFiniteMagnitude
}

var results = TrialResults()
for t in 0..<duration {
  let dacApparentTime = t - (t % dacResolution)
  let phase = dacApparentTime % sinePeriod
  let phaseNormalized = Float(phase) / Float(sinePeriod)
  let waveID = t / sinePeriod
  
  func createSignal() -> Float {
    if waveID < 0 || waveID >= waveCount {
      return 0
    }
    
    switch waveType {
    case .triangle:
      return triangleWave(phaseNormalized: phaseNormalized)
    case .polynomial(let includeOutskirts):
      let hasStartOutskirt = includeOutskirts && (waveID == 0)
      let hasEndOutskirt = includeOutskirts && (waveID == waveCount - 1)
      
      let x = 6 * phaseNormalized
      let waveValue = polynomialWave(
        x: x,
        hasStartOutskirt: hasStartOutskirt,
        hasEndOutskirt: hasEndOutskirt)
      
      var y = waveValue * 0.5 / polynomialWaveAmplitude
      if !includeOutskirts {
        y += 0.5
      }
      return y
    case .sine:
      return sineWave(phaseNormalized: phaseNormalized)
    }
  }
  
  let signal = Double(createSignal())
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
  
  if t % 20 == 0 {
    print("t = \(t) μs", terminator: " | ")
    print("signal = \(format(signal))", terminator: " | ")
    print("biquad = \(format(filtered))", terminator: " | ")
    print("error = \(format(error))", terminator: " | ")
    print()
  }
  
  func accumulateError(into accumulator: inout Double) {
    let errorMagnitude = error.magnitude
    if errorMagnitude > accumulator {
      accumulator = errorMagnitude
    }
  }
  
  if waveID == 0 {
    accumulateError(into: &results.errorStart)
  } else if waveID > waveCount - 1 {
    accumulateError(into: &results.errorEnd)
  } else if waveID < waveCount - 1 {
    accumulateError(into: &results.errorAC)
    
    var shifted = filtered
    if case .polynomial(true) = waveType {
      shifted += 0.5
    }
    
    if shifted > results.maximumAC {
      results.maximumAC = shifted
    }
    if shifted < results.minimumAC {
      results.minimumAC = shifted
    }
  }
}

let actualFrequency = 1e6 / Float(sinePeriod)
print(String(format: "%.1f", actualFrequency), terminator: ", ")
print(Float(results.errorStart), terminator: ", ")
print(Float(results.errorAC), terminator: ", ")
print(Float(results.errorEnd), terminator: ", ")
print(Float(results.maximumAC - 1), terminator: ", ")
print(Float(-results.minimumAC), terminator: ", ")
print()
