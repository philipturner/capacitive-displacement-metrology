//
//  MainFile.swift
//  Accelerometer
//
//  Created by Philip Turner on 11/17/24.
//

import Accelerate.vecLib
import ComplexModule

let samplingRate: Int = 512

// Prints a table to the console, which characterizes the position noise.
// - sequence: raw accelerations (in m/s^2) from the accelerometer
func reportTable(
  sequence: [SIMD4<Double>],
  transferFunction: (Float) -> Float
) {
  let accelerationNSD_original = noiseSpectralDensity(sequence)
  let startingPoint = extrapolationStartingPoint(accelerationNSD_original)
  
  // Utility that applies the transfer function.
  func applyTransferFunction(
    frequencyDomainSequence: [SIMD4<Float>]
  ) -> [SIMD4<Float>] {
    var output: [SIMD4<Float>] = []
    for inputDataPoint in frequencyDomainSequence {
      let frequency = inputDataPoint[0]
      let inputXYZ = SIMD3(
        inputDataPoint[1],
        inputDataPoint[2],
        inputDataPoint[3])
      
      // Multiply by the transfer function.
      let gainValue = transferFunction(frequency)
      let outputXYZ = inputXYZ * gainValue
      let outputDataPoint = SIMD4(
        frequency,
        outputXYZ[0],
        outputXYZ[1],
        outputXYZ[2])
      output.append(outputDataPoint)
    }
    return output
  }
  
  // Add whitespace to separate the table from preceding text.
  print()
  
  // Add the rows for extrapolation.
  let powers: [Float] = [-0.5, -1.0, -1.5, -2.0, -2.5]
  for power in powers {
    // The nominal 'power' is for position. To find the power for acceleration,
    // add two.
    let accelerationPower = power + 2
    let accelerationNSD_tail = extrapolation(
      startingPoint: startingPoint, power: accelerationPower)
    
    // Apply the transfer function.
    var accelerationNSD = accelerationNSD_original + accelerationNSD_tail
    accelerationNSD = applyTransferFunction(
      frequencyDomainSequence: accelerationNSD)
    
    // Display the table row.
    let powerRepr = String(format: "%.1f", power)
    let row = tableRow(accelerationNSD: accelerationNSD)
    print("x = f^\(powerRepr)       | \(row)")
  }
  
  // Add the row for without extrapolation.
  do {
    // Apply the transfer function.
    var accelerationNSD = accelerationNSD_original
    accelerationNSD = applyTransferFunction(
      frequencyDomainSequence: accelerationNSD)
    
    // Display the table row.
    let row = tableRow(accelerationNSD: accelerationNSD)
    print("no extrapolation | \(row)")
  }
  
  // Add the row for exact quantities.
  do {
    let acceleration3D = trueNoiseEnvelope(
      timeDomainSequence: sequence)
    let acceleration1D = (acceleration3D * acceleration3D).sum().squareRoot()
    let a = "\(format(distance: acceleration1D / 1e6))/ms^2"
    print("exact            |          |             | \(a)")
  }
}

// Utility function for getting just the f^-2.0 row of the table.
//
// Input:
// - sequence: absolute acceleration over time, in SI units
// - transfer function: accepts frequency in units of Hz
//
// Returns:
// - vector lane 0: position noise, in SI units
// - vector lane 1: position noise, in SI units
func noiseInverseSquareScaling(
  sequence: [SIMD4<Double>],
  transferFunction: (Float) -> Float
) -> SIMD2<Float> {
  let accelerationNSD_original = noiseSpectralDensity(sequence)
  let startingPoint = extrapolationStartingPoint(accelerationNSD_original)
  
  // The nominal 'power' is for position. To find the power for acceleration,
  // add two.
  let power: Float = -2
  let accelerationPower = power + 2
  let accelerationNSD_tail = extrapolation(
    startingPoint: startingPoint, power: accelerationPower)
  
  // Utility that applies the transfer function.
  func applyTransferFunction(
    frequencyDomainSequence: [SIMD4<Float>]
  ) -> [SIMD4<Float>] {
    var output: [SIMD4<Float>] = []
    for inputDataPoint in frequencyDomainSequence {
      let frequency = inputDataPoint[0]
      let inputXYZ = SIMD3(
        inputDataPoint[1],
        inputDataPoint[2],
        inputDataPoint[3])
      
      // Multiply by the transfer function.
      let gainValue = transferFunction(frequency)
      let outputXYZ = inputXYZ * gainValue
      let outputDataPoint = SIMD4(
        frequency,
        outputXYZ[0],
        outputXYZ[1],
        outputXYZ[2])
      output.append(outputDataPoint)
    }
    return output
  }
  
  // Apply the transfer function.
  var accelerationNSD = accelerationNSD_original + accelerationNSD_tail
  accelerationNSD = applyTransferFunction(
    frequencyDomainSequence: accelerationNSD)
  
  // Derive position and velocity from acceleration.
  var positionNSD: [SIMD4<Float>] = []
  var velocityNSD: [SIMD4<Float>] = []
  for dataPoint in accelerationNSD {
    let frequency = dataPoint[0]
    let accelerationXYZ = SIMD3(
      dataPoint[1],
      dataPoint[2],
      dataPoint[3])
    
    let ω = 2 * Float.pi * frequency
    let velocityXYZ = accelerationXYZ / ω
    let positionXYZ = accelerationXYZ / (ω * ω)
    
    let positionPoint = SIMD4(
      frequency,
      positionXYZ[0],
      positionXYZ[1],
      positionXYZ[2])
    let velocityPoint = SIMD4(
      frequency,
      velocityXYZ[0],
      velocityXYZ[1],
      velocityXYZ[2])
    positionNSD.append(positionPoint)
    velocityNSD.append(velocityPoint)
  }
  
  // Calculate all statistical quantities.
  let position3D = integratedNoiseEnvelope(
    frequencyDomainSequence: positionNSD)
  let velocity3D = integratedNoiseEnvelope(
    frequencyDomainSequence: velocityNSD)
  
  // Combine the X, Y, and Z noise with root-square summation.
  let position1D = (position3D * position3D).sum().squareRoot()
  let velocity1D = (velocity3D * velocity3D).sum().squareRoot()
  
  return SIMD2(position1D, velocity1D)
}

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

// Utility for formatting distance measurements.
func format(distance: Float) -> String {
  var unit: String
  var number: Float
  
  // Pick the order of magnitude.
  if distance < 999 * 1e-12 {
    unit = "pm"
    number = distance / 1e-12
  } else if distance < 999 * 1e-9 {
    unit = "nm"
    number = distance / 1e-9
  } else if distance < 999 * 1e-6 {
    unit = "μm"
    number = distance / 1e-6
  } else if distance < 999 * 1e-3 {
    unit = "mm"
    number = distance / 1e-3
  } else {
    return " >1.0  m"
  }
  
  // Pad the text to a fixed number of characters.
  var formattedNumber = String(format: "%.1f", number)
  while formattedNumber.count < 5 {
    formattedNumber = " " + formattedNumber
  }
  
  // Combine the numerical representation with the unit.
  return formattedNumber + " " + unit
}

// Calculate and display the 0th, 1st and 2nd derivatives of position.
func tableRow(accelerationNSD: [SIMD4<Float>]) -> String {
  // Derive position and velocity from acceleration.
  var positionNSD: [SIMD4<Float>] = []
  var velocityNSD: [SIMD4<Float>] = []
  for dataPoint in accelerationNSD {
    let frequency = dataPoint[0]
    let accelerationXYZ = SIMD3(
      dataPoint[1],
      dataPoint[2],
      dataPoint[3])
    
    let ω = 2 * Float.pi * frequency
    let velocityXYZ = accelerationXYZ / ω
    let positionXYZ = accelerationXYZ / (ω * ω)
    
    let positionPoint = SIMD4(
      frequency,
      positionXYZ[0],
      positionXYZ[1],
      positionXYZ[2])
    let velocityPoint = SIMD4(
      frequency,
      velocityXYZ[0],
      velocityXYZ[1],
      velocityXYZ[2])
    positionNSD.append(positionPoint)
    velocityNSD.append(velocityPoint)
  }
  
  // Calculate all statistical quantities.
  let position3D = integratedNoiseEnvelope(
    frequencyDomainSequence: positionNSD)
  let velocity3D = integratedNoiseEnvelope(
    frequencyDomainSequence: velocityNSD)
  let acceleration3D = integratedNoiseEnvelope(
    frequencyDomainSequence: accelerationNSD)
  
  // Combine the X, Y, and Z noise with root-square summation.
  let position1D = (position3D * position3D).sum().squareRoot()
  let velocity1D = (velocity3D * velocity3D).sum().squareRoot()
  let acceleration1D = (acceleration3D * acceleration3D).sum().squareRoot()
  
  // Display the table row.
  let x = "\(format(distance: position1D))"
  let v = "\(format(distance: velocity1D / 1e3))/ms"
  let a = "\(format(distance: acceleration1D / 1e6))/ms^2"
  return "\(x) | \(v) | \(a)"
}

// Fill empty samples with the nearest neighbor on the left.
func fillMissingSamples(
  _ input: [SIMD4<Double>?]
) -> [SIMD4<Double>] {
  // Initialize the 'nearest sample' variable.
  guard input.count > 0,
        var nearestSample = input[0] else {
    fatalError("Could not initialize 'nearest sample'.")
  }
  
  // Generate the output.
  var output: [SIMD4<Double>] = []
  for sample in input {
    if let sample {
      nearestSample = sample
    }
    output.append(nearestSample)
  }
  
  // Check the integrity of the output.
  guard output.count == input.count else {
    fatalError("Output data stream had different size than input stream.")
  }
  return output
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
    guard k > 0, f <= 50 else {
      continue
    }
    
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

// Take the RMS over all frequencies between 40 Hz and 50 Hz.
func extrapolationStartingPoint(
  _ accelerationNSD: [SIMD4<Float>]
) -> SIMD3<Float> {
  var integral: SIMD3<Float> = .zero
  var count: Int = .zero
  for dataPoint in accelerationNSD {
    guard dataPoint[0] >= 40, dataPoint[0] <= 50 else {
      continue
    }
    
    let xyz = SIMD3(
      dataPoint[1],
      dataPoint[2],
      dataPoint[3])
    integral += xyz * xyz
    count += 1
  }
  
  var rms = integral
  rms /= Float(count)
  rms.formSquareRoot()
  
  // Correct for the 1/f scaling of acceleration between 45 Hz and 50 Hz.
  let rms50 = rms * 45.0 / 50.0
  return rms50
}

// Utility function for generating an extrapolation.
func extrapolation(
  startingPoint: SIMD3<Float>,
  power: Float
) -> [SIMD4<Float>] {
  var output: [SIMD4<Float>] = []
  
  var frequency: Float = 50
  while frequency <= 1e12 {
    frequency *= 1.02
    
    let frequencyRatio = frequency / 50
    let amplitudeRatio = pow(frequencyRatio, power)
    
    let xyz = startingPoint * amplitudeRatio
    let dataPoint = SIMD4(
      frequency,
      xyz[0],
      xyz[1],
      xyz[2])
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

// Low-pass filters:
// - negativeStiffness
// - springSuspensionVoigtlander (1 Hz, 2nd-order, Q = 5)
// - twoStageSpringSuspension (2.4 Hz, 4th-order, Q = TBD)
// - springEddyCurrent (3 Hz, 2nd-order, Q = 3)
// - rubberPads (5 Hz, 2nd-order, Q = 15)
// - fiveStageHybrid (33 Hz, 4th-order, Q = undefined)
// - eightStage220Hz (92 Hz, 16th-order, Q = undefined)
// - eightStage700Hz (295 Hz, 16th-order, Q = undefined)
//
// Air table:
// - airTable (1.7 Hz, 2nd-order, Q = 0.5)
// - airTable (1.7 Hz, 2nd-order, Q = 1)
// - airTable (1.7 Hz, 2nd-order, Q = 3)
// - airTable (1.7 Hz, 2nd-order, Q = 10)
// - airTable (1.7 Hz, 2nd-order, Q = 30)
//
// High-pass filters:
// - microscopeVoigtlander (1 kHz, 2nd-order, Q = 1000)
// - typicalStructure (3 kHz, 2nd-order, Q = 30)

func transferFunction(ω: Float) -> Float {
  return typicalStructure(ω: ω)
}

// Displaying data at 20 points/decade
// 0.1 Hz to 10 kHz
for pointID in (-1 * 20)...(4 * 20) {
  let frequency = pow(10, Float(pointID) / 20)
  
  let ω = frequency * (2 * Float.pi)
  let output = transferFunction(ω: ω)
  print(output)
}
