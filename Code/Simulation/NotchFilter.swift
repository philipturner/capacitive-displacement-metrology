import Foundation

enum BiquadFilterType {
  case secondOrderLowpass
  case notch
}

struct BiquadFilterDescriptor {
  var resonanceFrequency: Double?
  var samplingFrequency: Double?
  var Q: Double?
  var type: BiquadFilterType?
}

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
          let Q = descriptor.Q,
          let type = descriptor.type else {
      fatalError("Descriptor was incomplete.")
    }
    
    let ω0 = 2 * Double.pi * resonanceFrequency / samplingFrequency
    let α = sin(ω0) / (2 * Q)
    
    switch type {
    case .secondOrderLowpass:
      let b0 = (1 - cos(ω0)) / 2
      let b1 = 1 - cos(ω0)
      let b2 = (1 - cos(ω0)) / 2
      let a0 = 1 + α
      let a1 = -2 * cos(ω0)
      let a2 = 1 - α
      
      self.b = SIMD3(b0, b1, b2)
      self.a = SIMD3(a0, a1, a2)
      
    case .notch:
      let b0: Double = 1
      let b1 = -2 * cos(ω0)
      let b2: Double = 1
      let a0 = 1 + α
      let a1 = -2 * cos(ω0)
      let a2 = 1 - α
      
      self.b = SIMD3(b0, b1, b2)
      self.a = SIMD3(a0, a1, a2)
    }
    
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

func createLowpassFilter() -> BiquadFilter {
  var filterDesc = BiquadFilterDescriptor()
  filterDesc.resonanceFrequency = 1470
  filterDesc.samplingFrequency = 1_000_000
  filterDesc.Q = 31
  filterDesc.type = .secondOrderLowpass
  return BiquadFilter(descriptor: filterDesc)
}

func createNotchFilter() -> BiquadFilter {
  var filterDesc = BiquadFilterDescriptor()
  filterDesc.resonanceFrequency = 1543
  filterDesc.samplingFrequency = 1e6 / 12
  filterDesc.Q = 0.5
  filterDesc.type = .notch
  return BiquadFilter(descriptor: filterDesc)
}

var lowpassFilter = createLowpassFilter()
var notchFilter = createNotchFilter()
var controlledPosition: Double = .zero
let desiredPosition: Double = 1

// f0 = 1470, Q = 31
//
// no feedback
// 18 ms to settle 10%
// 33 ms to settle 1%
//
// === Normal integrator ===
//
// 20 ms integrator time lag
// 21 ms to settle 10%
// 40 ms to settle 1%
//
// 15 ms integrator time lag
// 22 ms to settle 10%
// 42 ms to settle 1%
//
// 10 ms integrator time lag
// 25 ms to settle 10%
// 49 ms to settle 1%
//
// 8 ms integrator time lag
// 28 ms to settle 10%
// 55 ms to settle 1%
//
// 5 ms integrator time lag
// 48 ms to settle 10%
// 95 ms to settle 1%
//
// 4 ms integrator time lag
// 94 ms to settle 10%
// 190 ms to settle 1%
//
// 3 ms integrator time lag
// diverges
//
// === Notch filter: fc = 1617, Q = 2.0 ===
//
// 4 ms integrator time lag
// 19 ms to settle 10%
// 36 ms to settle 1%
//
// 2 ms integrator time lag
// 22 ms to settle 10%
// 41 ms to settle 1%
//
// 1 ms integrator time lag
// 39 ms to settle 10%
// 76 ms to settle 1%
//
// 800 μs integrator time lag
// 108 ms to settle 10%
// 218 ms to settle 1%
//
// 750 μs integrator time lag
// does not settle after 300 ms
//
// === Notch filter: fc = 1617, Q = 1.0 ===
//
// 4 ms integrator time lag
// 17 ms to settle 10%
// 32 ms to settle 1%
//
// 2 ms integrator time lag
// 17 ms to settle 10%
// 32 ms to settle 1%
//
// 1 ms integrator time lag
// 17 ms to settle 10%
// 33 ms to settle 1%
//
// 500 μs integrator time lag
// 21 ms to settle 10%
// 40 ms to settle 1%
//
// 350 μs
// 43 ms to settle 10%
// 87 ms to settle 1%
//
// 300 μs
// diverges
//
// === Notch filter: fc = 1617, Q = 0.5 ===
//
// 4 ms integrator time lag
// 18 ms to settle 10%
// 33 ms to settle 1%
//
// 2 ms integrator time lag
// 18 ms to settle 10%
// 33 ms to settle 1%
//
// 1 ms integrator time lag
// 17 ms to settle 10%
// 32 ms to settle 1%
//
// 500 μs integrator time lag
// 16 ms to settle 10%
// 31 ms to settle 1%
//
// 200 μs integrator time lag
// 15 ms to settle 10%
// 30 ms to settle 1%
//
// 150 μs integrator time lag
// 19 ms to settle 10%
// 42 ms to settle 1%
//
// 130 μs integrator time lag
// does not settle after 300 ms
//
// === Notch filter: fc = 1543, Q = 2.0 ===
//
// 1 ms integrator time lag
// 18 ms to settle 10%
// 34 ms to settle 1%
//
// 600 μs integrator time lag
// 25 ms to settle 10%
// 47 ms to settle 1%
//
// 500 μs integrator time lag
// 44 ms to settle 10%
// 86 ms to settle 1%
//
// 440 μs integrator time lag
// does not settle after 300 ms
//
// === Notch filter: fc = 1543, Q = 1.0 ===
//
// 1 ms integrator time lag
// 17 ms to settle 10%
// 31 ms to settle 1%
//
// 500 μs integrator time lag
// 16 ms to settle 10%
// 29 ms to settle 1%
//
// 300 μs integrator time lag
// 16 ms to settle 10%
// 29 ms to settle 1%
//
// 250 μs integrator time lag
// 18 ms to settle 10%
// 33 ms to settle 1%
//
// 200 μs integrator time lag
// diverges
//
// === Notch filter: fc = 1543, Q = 0.5 ===
//
// 1 ms integrator time lag
// 17 ms to settle 10%
// 32 ms to settle 1%
//
// 500 μs integrator time lag
// 16 ms to settle 10%
// 30 ms to settle 1%
//
// 300 μs integrator time lag
// 14 ms to settle 10%
// 27 ms to settle 1%
//
// 200 μs integrator time lag
// 13 ms to settle 10%
// 24 ms to settle 1%
//
// 100 μs integrator time lag
// 28 ms to settle 10%
// 45 ms to settle 1%
//
// 90 μs integrator time lag
// diverges

var recentHistory = [Double](repeating: 0, count: 2000)

var time10Percent: Int?
var time1Percent: Int?

for t in 0..<300_000 {
  if (t < 1000) {
    if (t > 100) {
      controlledPosition = desiredPosition
    }
  } else {
    if t % 12 == 0 {
      let actualPosition = lowpassFilter.y1
      let notchFiltered = notchFilter.update(input: actualPosition)
      
      let error = desiredPosition - actualPosition
      controlledPosition += error * 12 / 20000
    }
  }
  
  let actualPosition = lowpassFilter.update(input: controlledPosition)
  let notchFiltered = notchFilter.y1
  
  func format(_ number: Double) -> String {
    var output = String(format: "%.3f", number)
    
    let exampleString = "-X.XXX"
    while output.count < exampleString.count {
      output = " " + output
    }
    return output
  }
  
  if t % 10 == 0 {
    print("t = \(t) μs", terminator: " | ")
    print("controlled = \(format(controlledPosition))", terminator: " | ")
    print("actual = \(format(actualPosition))", terminator: " | ")
    print("notch = \(format(notchFiltered))", terminator: " | ")
    print()
  }
  
  // Automatically detect settling times
  recentHistory[t % 2000] = actualPosition
  
  if t % 1000 == 0 {
    var maxDeviation: Double = 0
    for sample in recentHistory {
      let dz = abs(sample - desiredPosition)
      maxDeviation = max(maxDeviation, dz)
    }
    
    if maxDeviation < 0.10 {
      if time10Percent == nil {
        time10Percent = t
      }
    }
    if maxDeviation < 0.01 {
      if time1Percent == nil {
        time1Percent = t
        break
      }
    }
  }
}

print()
if let time10Percent {
  print(time10Percent / 1000)
}
if let time1Percent {
  print(time1Percent / 1000)
}

// Tradeoff of bandwidth for accepting true signals
//
// === Integrator time lag only ===
//
// time lag = 4 ms
// 40 Hz - 0.705
// 200 Hz - 0.195
// 500 Hz - 0.079
// 1000 Hz - 0.040
//
// === Notch filter, integrator time lag not modeled ===
// fc = 1470 Hz
//
// Q = 2.0
// 500 Hz - 0.982
// 700 Hz - 0.956
// 1000 Hz - 0.845
// 1100 Hz - 0.762
// 1200 Hz - 0.633
// 1400 Hz - 0.192
// 1470 Hz - 0.000
// 1.5 ms (±10%) -> 106 Hz
// 600 μs (±5%) -> 265 Hz
// notch filter distortion: 1150 Hz -3 dB
//
// Q = 1.0
// 300 Hz - 0.978
// 400 Hz - 0.959
// 500 Hz - 0.933
// 700 Hz - 0.851
// 900 Hz - 0.714
// 1000 Hz - 0.620
// 1400 Hz - 0.097
// 1470 Hz - 0.000
// 500 μs (±10%) -> 318 Hz
// 250 μs (±5%) -> 637 Hz
// notch filter distortion: 900 Hz -3 dB
//
// Q = 0.5
// 200 Hz - 0.964
// 300 Hz - 0.920
// 500 Hz - 0.793
// 600 Hz - 0.714
// 700 Hz - 0.630
// 1000 Hz - 0.367
// 1400 Hz - 0.049
// 1470 Hz - 0.000
// 150 μs (±10%) -> 1061 Hz
// 110 μs (±5%) -> 1446 Hz
// notch filter distortion: 600 Hz -3 dB
let targetFrequency: Double = 600

do {
  // Don't change these.
  let filterFrequency: Double = 1470
  let Q: Double = 0.5
  
  let w = targetFrequency * 2 * Double.pi
  let w0 = filterFrequency * 2 * Double.pi
  
  let numerator = abs(w0 * w0 - w * w)
  var denominator = (w0 * w0 - w * w) * (w0 * w0 - w * w)
  denominator += (w0 * w / Q) * (w0 * w / Q)
  denominator = sqrt(denominator)
  
  let amplitude = numerator / denominator
  print()
  print("notch:", String(format: "%.3f", amplitude))
}

do {
  let filterTimeLag: Double = 4000e-6
  let filterFrequency = 1 / (2 * Double.pi * filterTimeLag)
  
  let w = targetFrequency * 2 * Double.pi
  let w0 = filterFrequency * 2 * Double.pi
  
  var denominator: Double = 1
  denominator += (w / w0) * (w / w0)
  denominator = sqrt(denominator)
  
  let amplitude = 1 / denominator
  print("integrator:", String(format: "%.3f", amplitude))
}
