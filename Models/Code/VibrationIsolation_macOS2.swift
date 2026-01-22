//
//  MainFile.swift
//  Accelerometer
//
//  Created by Philip Turner on 11/17/24.
//

import Accelerate.vecLib
import AVFAudio
import ComplexModule

let samplingRate: Int = 8000

// Utility function for integrating an arbitrary noise spectrum.
func integratedNoiseEnvelope(
  frequencyDomainSequence: [SIMD4<Float>]
) -> SIMD3<Float> {
  // Iterate over the data points.
  var variance: SIMD3<Float> = .zero
  for dataPointID in frequencyDomainSequence.indices {
    let dataPoint = frequencyDomainSequence[dataPointID]
    
    // Calculate df.
    var previousFrequency: Float
    if dataPointID == 0 {
      previousFrequency = 0
    } else {
      let previousDataPoint = frequencyDomainSequence[dataPointID - 1]
      previousFrequency = previousDataPoint[0]
    }
    let currentFrequency = dataPoint[0]
    let df = currentFrequency - previousFrequency
    
    // Integrate the x-component of acceleration.
    let amplitudeXYZ = SIMD3(
      dataPoint[1],
      dataPoint[2],
      dataPoint[3])
    variance += amplitudeXYZ * amplitudeXYZ * df
  }
  
  // Correct for the existence of negative frequencies.
  variance *= 2
  
  // Calculate the standard deviation and the 6σ interval.
  let standardDeviation = variance.squareRoot()
  return 6 * standardDeviation
}

// Utility function for calculating the true noise envelope.
func trueNoiseEnvelope(
  timeDomainSequence: [SIMD4<Double>]
) -> SIMD3<Float> {
  let originalSize = UInt32(timeDomainSequence.count)
  let truncatedSize = truncateToDivisibleSize(originalSize)
  
  // Reduce the mean across the data points.
  var mean: SIMD3<Float> = .zero
  for sampleID in 0..<truncatedSize {
    let sample = timeDomainSequence[Int(sampleID)]
    let amplitudeXYZ = SIMD3(
      Float(sample[1]),
      Float(sample[2]),
      Float(sample[3]))
    mean += amplitudeXYZ
  }
  mean /= Float(truncatedSize)
  
  // Reduce the variance across the data points.
  var variance: SIMD3<Float> = .zero
  for sampleID in 0..<truncatedSize {
    let sample = timeDomainSequence[Int(sampleID)]
    let amplitudeXYZ = SIMD3(
      Float(sample[1]),
      Float(sample[2]),
      Float(sample[3]))
    variance += (amplitudeXYZ - mean) * (amplitudeXYZ - mean)
  }
  variance /= Float(truncatedSize - 1)
  
  // Calculate the standard deviation and the 6σ interval.
  let standardDeviation = variance.squareRoot()
  return 6 * standardDeviation
}

// MARK: - Generate Frequency Domain Data

// Clamp the sample size to something divisible by {1, 3, 5, 7} * 2^n.
func truncateToDivisibleSize(_ inputCount: UInt32) -> UInt32 {
  let leadingZeroBitCount = inputCount.leadingZeroBitCount
  let trailingZeroBitCount = 32 - leadingZeroBitCount
  guard trailingZeroBitCount >= 3 else {
    fatalError("Number was too small.")
  }
  
  var outputCount = inputCount >> (trailingZeroBitCount - 3)
  if outputCount == 7 {
    // Apple's documentation suggests only 2, 3, and 5 are optimized.
    outputCount = 6
  }
  outputCount = outputCount << (trailingZeroBitCount - 3)
  return outputCount
}

// Executes a discrete Fourier transform.
func fourierTransform(
  _ input: [Float]
) -> (real: [Float], imaginary: [Float]) {
  // Prepare the operation.
  let setup = vDSP_DFT_zop_CreateSetup(
    nil,
    UInt(input.count),
    .FORWARD)
  guard let setup else {
    fatalError("Could not set up Fourier transform.")
  }
  defer {
    vDSP_DFT_DestroySetup(setup)
  }
  
  // Generate the outputs.
  let inputImaginary = [Float](repeating: 0, count: input.count)
  var outputReal = [Float](repeating: 0, count: input.count)
  var outputImaginary = [Float](repeating: 0, count: input.count)
  vDSP_DFT_Execute(
    setup,
    input,
    inputImaginary,
    &outputReal,
    &outputImaginary)
  
  return (outputReal, outputImaginary)
}

func complexAmplitudes(
  _ input: (real: [Float], imaginary: [Float])
) -> [Float] {
  let dataPointCount = input.real.count
  
  var output: [Float] = []
  for i in 0..<dataPointCount {
    let real = input.real[i]
    let imaginary = input.imaginary[i]
    
    let amplitude = (real * real + imaginary * imaginary).squareRoot()
    output.append(amplitude)
  }
  return output
}

// Converts acceleration (time domain) to acceleration noise spectral density
// (frequency domain). Does not alter the units for acceleration.
func noiseSpectralDensity(
  _ sequence: [SIMD4<Double>]
) -> [SIMD4<Float>] {
  let originalSize = UInt32(sequence.count)
  let truncatedSize = truncateToDivisibleSize(originalSize)
  
  func transformToFourier(laneID: Int) -> [Float] {
    var fourierInput: [Float] = []
    for sampleID in 0..<truncatedSize {
      let sample = sequence[Int(sampleID)]
      let sampleLane = Float(sample[laneID])
      fourierInput.append(sampleLane)
    }
    
    let fourierOutput = fourierTransform(fourierInput)
    let fourierAmplitude = complexAmplitudes(fourierOutput)
    return fourierAmplitude
  }
  
  let amplitudeX = transformToFourier(laneID: 1)
  let amplitudeY = transformToFourier(laneID: 2)
  let amplitudeZ = transformToFourier(laneID: 3)
  
  var output: [SIMD4<Float>] = []
  for k in 0..<truncatedSize {
    let Δt = 1 / Float(samplingRate)
    let f = Float(k) / (Float(truncatedSize) * Δt)
    
    let coefficient = ((Δt * Δt) / (Float(truncatedSize) * Δt)).squareRoot()
    let amplitudes = SIMD3<Float>(
      amplitudeX[Int(k)],
      amplitudeY[Int(k)],
      amplitudeZ[Int(k)])
    let dataPoint = SIMD4(
      f,
      coefficient * amplitudes[0],
      coefficient * amplitudes[1],
      coefficient * amplitudes[2])
    output.append(dataPoint)
  }
  return output
}

// MARK: - Transfer Functions

// Transfer function for the spring suspension from the SPM textbook.
func springSuspensionVoigtlander(ω: Float) -> Float {
  // 1 Hz isolator, Q-factor = 5
  let ω0: Float = 1 * (2 * Float.pi)
  let Q: Float = 5
  let γ: Float = ω0 / Q
  
  func x2(ω: Float) -> Complex<Float> {
    var output = Complex(ω0 * ω0)
    output += Complex(imaginary: 1) * Complex(γ * ω)
    return output
  }
  func x1(ω: Float) -> Complex<Float> {
    var output = Complex(ω0 * ω0 - ω * ω)
    output += Complex(imaginary: 1) * Complex(γ * ω)
    return output
  }
  func κ(ω: Float) -> Float {
    let numerator = x2(ω: ω)
    let denominator = x1(ω: ω)
    let output = numerator / denominator
    return output.lengthSquared.squareRoot()
  }
  
  return κ(ω: ω)
}

// Transfer function for the tunneling assembly from the SPM textbook.
func microscopeVoigtlander(ω: Float) -> Float {
  // 1000 Hz tunneling assembly, Q-factor = 100
  let ωSTM: Float = 1000 * (2 * Float.pi)
  let Q: Float = 100
  let γ: Float = ωSTM / Q
  
  func x3x2(ω: Float) -> Complex<Float> {
    return Complex(ω * ω)
  }
  func x2(ω: Float) -> Complex<Float> {
    var output = Complex(ωSTM * ωSTM - ω * ω)
    output += Complex(imaginary: 1) * Complex(γ * ω)
    return output
  }
  func κ(ω: Float) -> Float {
    let numerator = x3x2(ω: ω)
    let denominator = x2(ω: ω)
    let output = numerator / denominator
    return output.lengthSquared.squareRoot()
  }
  
  return κ(ω: ω)
}

// The 'td1' isolator from Pohl (1986).
func springEddyCurrent(ω: Float) -> Float {
  // 3 Hz isolator, Q-factor = 3
  let ω0: Float = 3 * (2 * Float.pi)
  let Q: Float = 3
  let γ: Float = ω0 / Q
  
  func x2(ω: Float) -> Complex<Float> {
    var output = Complex(ω0 * ω0)
    output += Complex(imaginary: 1) * Complex(γ * ω)
    return output
  }
  func x1(ω: Float) -> Complex<Float> {
    var output = Complex(ω0 * ω0 - ω * ω)
    output += Complex(imaginary: 1) * Complex(γ * ω)
    return output
  }
  func κ(ω: Float) -> Float {
    let numerator = x2(ω: ω)
    let denominator = x1(ω: ω)
    let output = numerator / denominator
    return output.lengthSquared.squareRoot()
  }
  
  return κ(ω: ω)
}

// The 'td2' isolator from Pohl (1986).
func rubberPads(ω: Float) -> Float {
  // 5 Hz isolator, Q-factor = 15
  let ω0: Float = 5 * (2 * Float.pi)
  let Q: Float = 15
  let γ: Float = ω0 / Q
  
  func x2(ω: Float) -> Complex<Float> {
    var output = Complex(ω0 * ω0)
    output += Complex(imaginary: 1) * Complex(γ * ω)
    return output
  }
  func x1(ω: Float) -> Complex<Float> {
    var output = Complex(ω0 * ω0 - ω * ω)
    output += Complex(imaginary: 1) * Complex(γ * ω)
    return output
  }
  func κ(ω: Float) -> Float {
    let numerator = x2(ω: ω)
    let denominator = x1(ω: ω)
    let output = numerator / denominator
    return output.lengthSquared.squareRoot()
  }
  
  return κ(ω: ω)
}

// The "Sa" structure from Pohl (1986).
func typicalStructure(ω: Float) -> Float {
  // 3000 Hz tunneling assembly, Q-factor = 30
  let ωSTM: Float = 3000 * (2 * Float.pi)
  let Q: Float = 30
  let γ: Float = ωSTM / Q
  
  func x3x2(ω: Float) -> Complex<Float> {
    return Complex(ω * ω)
  }
  func x2(ω: Float) -> Complex<Float> {
    var output = Complex(ωSTM * ωSTM - ω * ω)
    output += Complex(imaginary: 1) * Complex(γ * ω)
    return output
  }
  func κ(ω: Float) -> Float {
    let numerator = x3x2(ω: ω)
    let denominator = x2(ω: ω)
    let output = numerator / denominator
    return output.lengthSquared.squareRoot()
  }
  
  return κ(ω: ω)
}

// The "Sb" structure from Pohl (1986).
func bestPiezoCeramic(ω: Float) -> Float {
  // 100 kHz tunneling assembly, Q-factor = 100
  let ωSTM: Float = 100_000 * (2 * Float.pi)
  let Q: Float = 100
  let γ: Float = ωSTM / Q
  
  func x3x2(ω: Float) -> Complex<Float> {
    return Complex(ω * ω)
  }
  func x2(ω: Float) -> Complex<Float> {
    var output = Complex(ωSTM * ωSTM - ω * ω)
    output += Complex(imaginary: 1) * Complex(γ * ω)
    return output
  }
  func κ(ω: Float) -> Float {
    let numerator = x3x2(ω: ω)
    let denominator = x2(ω: ω)
    let output = numerator / denominator
    return output.lengthSquared.squareRoot()
  }
  
  return κ(ω: ω)
}

// Simplified model of eight-stage, -120 dB at 700 Hz from Oliva (1992).
//
// This model omits resonance of the plate stack, and important non-ideality.
func eightStage700Hz(ω: Float) -> Float {
  let f0: Float = 295.188
  let n: Float = 8
  
  let f = ω / (2 * Float.pi)
  let f_rel = f / f0
  var denominator = pow(f_rel, 2 * n)
  denominator = 1 + denominator
  
  return 1 / denominator
}

// Simplified model of eight-stage, -120 dB at 220 Hz from Oliva (1992).
//
// This model omits resonance of the plate stack, and important non-ideality.
func eightStage220Hz(ω: Float) -> Float {
  let f0: Float = 92.7732
  let n: Float = 8
  
  let f = ω / (2 * Float.pi)
  let f_rel = f / f0
  var denominator = pow(f_rel, 2 * n)
  denominator = 1 + denominator
  
  return 1 / denominator
}

// Simplified model of the isolator in Figure 17 from Okano (1987).
//
// Although there are five plates, the scaling on the chart shows n^-4
// behavior. This matches the behavior of a two-stage model from Oliva (1992).
func fiveStageHybrid(ω: Float) -> Float {
  let f0: Float = 33.7873
  let n: Float = 2
  
  let f = ω / (2 * Float.pi)
  let f_rel = f / f0
  var denominator = pow(f_rel, 2 * n)
  denominator = 1 + denominator
  
  return 1 / denominator
}

// Complete 1D model of the two-stage spring isolator from Okano (1987).
func twoStageSpringSuspension(ω: Float) -> Float {
  let s = Complex(imaginary: 1) * Complex(ω)
  
  // Specify the parameters of each part in the system.
  let M1 = Complex<Float>(2.4)
  let M2 = Complex<Float>(2.9)
  let K1 = Complex<Float>(800)
  let K2 = Complex<Float>(700)
  let C1 = Complex<Float>(0)
  let C2 = Complex<Float>(20)
  
  // Data structure to encapsulate linear algebra on complex numbers.
  typealias ComplexMatrix = (
    a: Complex<Float>, b: Complex<Float>,
    c: Complex<Float>, d: Complex<Float>)
  
  // Construct the matrix.
  // - A + sB
  // - [a b]
  //   [c d]
  var matrix: ComplexMatrix
  do {
    var matrix_a: Complex<Float> = (s * s * M1) + K1 + K2
    var matrix_b: Complex<Float> = -K2
    var matrix_c: Complex<Float> = -K2
    var matrix_d: Complex<Float> = (s * s * M2) + K2
    matrix_a += s * (C1 + C2)
    matrix_b += s * (-C2)
    matrix_c += s * (-C2)
    matrix_d += s * (C2)
    
    matrix = (matrix_a, matrix_b, matrix_c, matrix_d)
  }
  
  // Invert the matrix.
  var inverse: ComplexMatrix
  do {
    let determinant = matrix.a * matrix.d - matrix.b * matrix.c
    let inverse_a = matrix.d / determinant
    let inverse_b = -matrix.b / determinant
    let inverse_c = -matrix.c / determinant
    let inverse_d = matrix.a / determinant
    
    inverse = (inverse_a, inverse_b, inverse_c, inverse_d)
  }
  
  // Utility for matrix multiplication.
  func multiply(
    lhs: ComplexMatrix,
    rhs: ComplexMatrix
  ) -> ComplexMatrix {
    let output_a = lhs.a * rhs.a + lhs.b * rhs.c
    let output_c = lhs.c * rhs.a + lhs.d * rhs.c
    let output_b = lhs.a * rhs.b + lhs.b * rhs.d
    let output_d = lhs.c * rhs.b + lhs.d * rhs.d
    
    return (output_a, output_b, output_c, output_d)
  }
  
  // Solve the linear system.
  let Y = K1 + s * C1
  let vectorFormY: ComplexMatrix = (Y, 0, 0, 0)
  let multipliedSolution = multiply(lhs: inverse, rhs: vectorFormY)
  let transferFunction02 = multipliedSolution.c
  
  return transferFunction02.magnitude
}

// The lowest-frequency air table from Oliva (1998).
//
// Damping coefficient was not reported, so we have to analyze a range of them.
func airTable(ω: Float, Q: Float) -> Float {
  // 1.7 Hz isolator, Q-factor falls between 0.5 and 30
  let ω0: Float = 1.7 * (2 * Float.pi)
  let γ: Float = ω0 / Q
  
  func x2(ω: Float) -> Complex<Float> {
    var output = Complex(ω0 * ω0)
    output += Complex(imaginary: 1) * Complex(γ * ω)
    return output
  }
  func x1(ω: Float) -> Complex<Float> {
    var output = Complex(ω0 * ω0 - ω * ω)
    output += Complex(imaginary: 1) * Complex(γ * ω)
    return output
  }
  func κ(ω: Float) -> Float {
    let numerator = x2(ω: ω)
    let denominator = x1(ω: ω)
    let output = numerator / denominator
    return output.lengthSquared.squareRoot()
  }
  
  return κ(ω: ω)
}

// Lookup table that reproduces the official graph from Minus K.
//
// 0.3, 1.1
// 0.4, 2.0
// 0.5, 4.0
// 0.6, 1.5
// 0.7, 1.0
// 1, 0.32
// 2, 0.08
// 3, 0.029
// 4, 0.017
// 5, 0.011
// 6, 0.0085
// 7, 0.007
// 10, 0.004
// 20, 0.0023
// 30, 0.0019
// 50, 0.0017
// plateau at 50 Hz
//
func negativeStiffness(ω: Float) -> Float {
  let f = ω / (2 * Float.pi)
  
  if f <= 0.2 {
    return 1.0
  } else if f >= 50 {
    return 0.0017
  }
  
  let lookupTable: [SIMD2<Float>] = [
    SIMD2<Float>(0.2, 1.0),
    SIMD2<Float>(0.3, 1.1),
    SIMD2<Float>(0.4, 2.0),
    SIMD2<Float>(0.5, 4.0),
    SIMD2<Float>(0.6, 1.5),
    SIMD2<Float>(0.7, 1.0),
    SIMD2<Float>(1, 0.32),
    SIMD2<Float>(2, 0.08),
    SIMD2<Float>(3, 0.029),
    SIMD2<Float>(4, 0.017),
    SIMD2<Float>(5, 0.011),
    SIMD2<Float>(6, 0.0085),
    SIMD2<Float>(7, 0.007),
    SIMD2<Float>(10, 0.004),
    SIMD2<Float>(20, 0.0023),
    SIMD2<Float>(30, 0.0019),
    SIMD2<Float>(50, 0.0017),
  ]
  
  // Iterate over the intervals of the lookup table.
  for elementID in lookupTable.indices {
    if elementID + 1 >= lookupTable.count {
      break
    }
    
    // Test whether the current interval is the correct one.
    let lowerBound = lookupTable[elementID]
    let upperBound = lookupTable[elementID + 1]
    guard lowerBound[0] <= f,
          upperBound[0] > f  else {
      continue
    }
    
    // Interpolate between the two bounds.
    let progress = (f - lowerBound[0]) / (upperBound[0] - lowerBound[0])
    let interpolated = upperBound[1] * progress + lowerBound[1] * (1 - progress)
    return interpolated
  }
  
  fatalError("Could not traverse the lookup table.")
}

// MARK: - Scripting

// TODO: Remember to save progress to repo

// TODO: Compare these two data sets:
// - https://github.com/Digiducer/matlab/blob/master/TMS%20Digital%20Audio%20Matlab%20Examples.pdf
// - https://docs.google.com/spreadsheets/d/176Aklm0jmut0bbd_DLOGd5mFAoFTXh9oIp-u1CQBKbU/edit?gid=1708820223#gid=1708820223

let path = "/Users/philipturner/Desktop/Example.wav"
let url = URL(filePath: path)
let audioFile = try! AVAudioFile(forReading: url)
print(audioFile.fileFormat)
print(audioFile.processingFormat)
print(audioFile.length)
print(audioFile.framePosition)
print()

/*
 https://www.modalshop.com/docs/themodalshoplibraries/software/usb-audio-interface-guide-man-0343.pdf
 
 62 49 1
 
 63 48 0
 64 53 5
 65 52 4
 66 52 4
 67 53 5
 68 52 4
 
 69 51 3
 70 54 6
 71 54 6
 72 55 7
 73 57 9
 
 74 55 7
 75 49 1
 76 57 9
 77 55 7
 78 50 2
 
 79 49 1
 80 52 4
 
 81 48 0
 82 54 6
 
 83 50 2
 84 51 3
 
 format version 1
 serial number: 054454
 CalA: 36679
 CalB: 71972
 date: June 23, 2014
 */
let channelCalibrations = SIMD2<Float>(36679, 71972) * 1.03214014

let audioBuffer = AVAudioPCMBuffer(
  pcmFormat: audioFile.processingFormat,
  frameCapacity: UInt32(audioFile.length))!
try! audioFile.read(into: audioBuffer)

print(audioBuffer.frameLength)
print(audioBuffer.stride)
print()

guard let floatChannelData = audioBuffer.floatChannelData else {
  fatalError("Not implemented.")
}

// Input: normalized float
// Output: G's
func createDataArray(
  channel: UnsafeMutablePointer<Float>,
  calibration: Float,
  pointCount: Int
) -> [Float] {
  var output: [Float] = []
  for i in 0..<pointCount {
    var dataPoint = channel[i]
    dataPoint *= 8388608
    dataPoint /= calibration
    dataPoint /= 9.80665
    output.append(dataPoint)
  }
  return output
}

func createFourChannelData() -> [SIMD4<Double>] {
  let dataArray0 = createDataArray(
    channel: floatChannelData[0],
    calibration: channelCalibrations[0],
    pointCount: Int(audioBuffer.frameLength))
  let dataArray1 = createDataArray(
    channel: floatChannelData[1],
    calibration: channelCalibrations[1],
    pointCount: Int(audioBuffer.frameLength))
  
  var output: [SIMD4<Double>] = []
  for pointID in 0..<Int(audioBuffer.frameLength) {
    let time = Double(pointID) / Double(samplingRate)
    let data0 = Double(dataArray0[pointID])
    let data1 = Double(dataArray1[pointID])
    
    let dataPoint = SIMD4(time, data0, data1, 0)
    output.append(dataPoint)
  }
  return output
}

let fourChannelData = createFourChannelData()
let nsd = noiseSpectralDensity(fourChannelData)
print("sample count =", nsd.count)
print("df =", Float(8000) / Float(nsd.count))
for i in nsd.indices {
  let dataPoint = SIMD4<Float>(nsd[i])
  print(i, dataPoint[0], dataPoint[1], dataPoint[2], dataPoint[3])
}

// Next, average a sub-range, where different parts of the logarithmic scale
// Get different treatments. Include 'df' as the 4th lane of the vector.
