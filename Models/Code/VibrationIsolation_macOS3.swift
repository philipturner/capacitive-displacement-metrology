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
) -> [SIMD4<Double>] {
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
  
  var output: [SIMD4<Double>] = []
  for k in 0..<truncatedSize {
    let Δt = 1 / Double(samplingRate)
    let f = Double(k) / (Double(truncatedSize) * Δt)
    
    let coefficient = ((Δt * Δt) / (Double(truncatedSize) * Δt)).squareRoot()
    let amplitudes = SIMD3<Double>(SIMD3<Float>(
      amplitudeX[Int(k)],
      amplitudeY[Int(k)],
      amplitudeZ[Int(k)]))
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

func createFrequenciesString() -> String {
  return """
0.25
0.50
0.75
1.00
1.25
1.50
1.75
2.00
2.25
2.50
2.75
3.00
3.25
3.50
3.75
4.00
4.25
4.50
4.75
5.00
5.25
5.50
6.25
7.50
8.75
10.00
11.25
12.50
14.38
16.88
19.38
21.88
24.38
26.88
29.38
31.88
34.38
36.88
39.38
41.88
44.38
46.88
49.38
51.88
55.63
60.63
65.63
70.63
75.63
80.63
85.63
90.63
95.63
100.63
105.63
110.63
115.63
120.63
125.63
0.049
0.098
0.146
0.195
0.244
0.293
0.342
0.391
0.439
0.488
0.537
0.586
0.635
0.684
0.732
0.781
0.830
0.879
0.928
0.977
1.025
1.074
1.123
1.172
1.221
1.270
1.318
1.367
1.416
1.465
1.514
1.563
1.611
1.660
1.709
1.758
1.807
1.855
1.904
1.953
2.002
2.051
2.100
2.148
2.197
2.246
2.295
2.344
2.393
2.441
2.490
2.539
2.588
2.637
2.686
2.734
2.783
2.832
2.881
2.930
2.979
3.027
3.076
3.125
3.174
3.223
3.271
3.320
3.369
3.418
3.467
3.516
3.564
3.613
3.662
3.711
3.760
3.809
3.857
3.906
3.955
4.004
4.053
4.102
4.150
4.199
4.248
4.297
4.346
4.395
4.443
4.492
4.541
4.590
4.639
4.688
4.736
4.785
4.834
4.883
4.932
4.980
5.029
5.078
5.127
5.176
5.225
5.273
5.322
5.371
5.420
5.469
5.518
5.566
5.615
5.664
5.713
5.762
5.811
5.859
5.908
5.957
6.006
6.055
6.104
6.152
6.201
6.250
6.299
6.348
6.396
6.445
6.494
6.543
6.592
6.641
6.689
6.738
6.787
6.836
6.885
6.934
6.982
7.031
7.080
7.129
7.178
7.227
7.275
7.324
7.373
7.422
7.471
7.520
7.568
7.617
7.666
7.715
7.764
7.813
7.861
7.910
7.959
8.008
8.057
8.105
8.154
8.203
8.252
8.301
8.350
8.398
8.447
8.496
8.545
8.594
8.643
8.691
8.740
8.789
8.838
8.887
8.936
8.984
9.033
9.082
9.131
9.180
9.229
9.277
9.326
9.375
9.424
9.473
9.521
9.570
9.619
9.668
9.717
9.766
9.814
9.863
9.912
9.961
10.010
10.059
10.107
10.156
10.205
10.254
10.303
10.352
10.400
10.449
10.498
10.547
10.596
10.645
10.693
10.742
10.791
10.840
10.889
10.938
10.986
11.035
11.084
11.133
11.182
11.230
11.279
11.328
11.377
11.426
11.475
11.523
11.572
11.621
11.670
11.719
11.768
11.816
11.865
11.914
11.963
12.012
12.061
12.109
12.158
12.207
12.256
12.305
12.354
12.402
12.451
12.500
12.598
12.695
12.793
12.891
12.988
13.086
13.184
13.281
13.379
13.477
13.574
13.672
13.770
13.867
13.965
14.063
14.160
14.258
14.355
14.453
14.551
14.648
14.746
14.844
14.941
15.039
15.137
15.234
15.332
15.430
15.527
15.625
15.723
15.820
15.918
16.016
16.113
16.211
16.309
16.406
16.504
16.602
16.699
16.797
16.895
16.992
17.090
17.188
17.285
17.383
17.480
17.578
17.676
17.773
17.871
17.969
18.066
18.164
18.262
18.359
18.457
18.555
18.652
18.750
18.848
18.945
19.043
19.141
19.238
19.336
19.434
19.531
19.629
19.727
19.824
19.922
20.020
20.117
20.215
20.313
20.410
20.508
20.605
20.703
20.801
20.898
20.996
21.094
21.191
21.289
21.387
21.484
21.582
21.680
21.777
21.875
21.973
22.070
22.168
22.266
22.363
22.461
22.559
22.656
22.754
22.852
22.949
23.047
23.145
23.242
23.340
23.438
23.535
23.633
23.730
23.828
23.926
24.023
24.121
24.219
24.316
24.414
24.512
24.609
24.707
24.805
24.902
25.000
25.195
25.391
25.586
25.781
25.977
26.172
26.367
26.563
26.758
26.953
27.148
27.344
27.539
27.734
27.930
28.125
28.320
28.516
28.711
28.906
29.102
29.297
29.492
29.688
29.883
30.078
30.273
30.469
30.664
30.859
31.055
31.250
31.445
31.641
31.836
32.031
32.227
32.422
32.617
32.813
33.008
33.203
33.398
33.594
33.789
33.984
34.180
34.375
34.570
34.766
34.961
35.156
35.352
35.547
35.742
35.938
36.133
36.328
36.523
36.719
36.914
37.109
37.305
37.500
37.695
37.891
38.086
38.281
38.477
38.672
38.867
39.063
39.258
39.453
39.648
39.844
40.039
40.234
40.430
40.625
40.820
41.016
41.211
41.406
41.602
41.797
41.992
42.188
42.383
42.578
42.773
42.969
43.164
43.359
43.555
43.750
43.945
44.141
44.336
44.531
44.727
44.922
45.117
45.313
45.508
45.703
45.898
46.094
46.289
46.484
46.680
46.875
47.070
47.266
47.461
47.656
47.852
48.047
48.242
48.438
48.633
48.828
49.023
49.219
49.414
49.609
49.805
50.000
50.391
50.781
51.172
51.563
51.953
52.344
52.734
53.125
53.516
53.906
54.297
54.688
55.078
55.469
55.859
56.250
56.641
57.031
57.422
57.813
58.203
58.594
58.984
59.375
59.766
60.156
60.547
60.938
61.328
61.719
62.109
62.500
62.891
63.281
63.672
64.063
64.453
64.844
65.234
65.625
66.016
66.406
66.797
67.188
67.578
67.969
68.359
68.750
69.141
69.531
69.922
70.313
70.703
71.094
71.484
71.875
72.266
72.656
73.047
73.438
73.828
74.219
74.609
75.000
75.391
75.781
76.172
76.563
76.953
77.344
77.734
78.125
78.516
78.906
79.297
79.688
80.078
80.469
80.859
81.250
81.641
82.031
82.422
82.813
83.203
83.594
83.984
84.375
84.766
85.156
85.547
85.938
86.328
86.719
87.109
87.500
87.891
88.281
88.672
89.063
89.453
89.844
90.234
90.625
91.016
91.406
91.797
92.188
92.578
92.969
93.359
93.750
94.141
94.531
94.922
95.313
95.703
96.094
96.484
96.875
97.266
97.656
98.047
98.438
98.828
99.219
99.609
100.000
100.781
101.563
102.344
103.125
103.906
104.688
105.469
106.250
107.031
107.813
108.594
109.375
110.156
110.938
111.719
112.500
113.281
114.063
114.844
115.625
116.406
117.188
117.969
118.750
119.531
120.313
121.094
121.875
122.656
123.438
124.219
125.000
125.781
126.563
127.344
128.125
128.906
129.688
130.469
131.250
132.031
132.813
133.594
134.375
135.156
135.938
136.719
137.500
138.281
139.063
139.844
140.625
141.406
142.188
142.969
143.750
144.531
145.313
146.094
146.875
147.656
148.438
149.219
150.000
150.781
151.563
152.344
153.125
153.906
154.688
155.469
156.250
157.031
157.813
158.594
159.375
160.156
160.938
161.719
162.500
163.281
164.063
164.844
165.625
166.406
167.188
167.969
168.750
169.531
170.313
171.094
171.875
172.656
173.438
174.219
175.000
175.781
176.563
177.344
178.125
178.906
179.688
180.469
181.250
182.031
182.813
183.594
184.375
185.156
185.938
186.719
187.500
188.281
189.063
189.844
190.625
191.406
192.188
192.969
193.750
194.531
195.313
196.094
196.875
197.656
198.438
199.219
200.000
201.563
203.125
204.688
206.250
207.813
209.375
210.938
212.500
214.063
215.625
217.188
218.750
220.313
221.875
223.438
225.000
226.563
228.125
229.688
231.250
232.813
234.375
235.938
237.500
239.063
240.625
242.188
243.750
245.313
246.875
248.438
250.000
251.563
253.125
254.688
256.250
257.813
259.375
260.938
262.500
264.063
265.625
267.188
268.750
270.313
271.875
273.438
275.000
276.563
278.125
279.688
281.250
282.813
284.375
285.938
287.500
289.063
290.625
292.188
293.750
295.313
296.875
298.438
300.000
301.563
303.125
304.688
306.250
307.813
309.375
310.938
312.500
314.063
315.625
317.188
318.750
320.313
321.875
323.438
325.000
326.563
328.125
329.688
331.250
332.813
334.375
335.938
337.500
339.063
340.625
342.188
343.750
345.313
346.875
348.438
350.000
351.563
353.125
354.688
356.250
357.813
359.375
360.938
362.500
364.063
365.625
367.188
368.750
370.313
371.875
373.438
375.000
376.563
378.125
379.688
381.250
382.813
384.375
385.938
387.500
389.063
390.625
392.188
393.750
395.313
396.875
398.438
400.000
403.125
406.250
409.375
412.500
415.625
418.750
421.875
425.000
428.125
431.250
434.375
437.500
440.625
443.750
446.875
450.000
453.125
456.250
459.375
462.500
465.625
468.750
471.875
475.000
478.125
481.250
484.375
487.500
490.625
493.750
496.875
500.000
503.125
506.250
509.375
512.500
515.625
518.750
521.875
525.000
528.125
531.250
534.375
537.500
540.625
543.750
546.875
550.000
553.125
556.250
559.375
562.500
565.625
568.750
571.875
575.000
578.125
581.250
584.375
587.500
590.625
593.750
596.875
600.000
603.125
606.250
609.375
612.500
615.625
618.750
621.875
625.000
628.125
631.250
634.375
637.500
640.625
643.750
646.875
650.000
653.125
656.250
659.375
662.500
665.625
668.750
671.875
675.000
678.125
681.250
684.375
687.500
690.625
693.750
696.875
700.000
703.125
706.250
709.375
712.500
715.625
718.750
721.875
725.000
728.125
731.250
734.375
737.500
740.625
743.750
746.875
750.000
753.125
756.250
759.375
762.500
765.625
768.750
771.875
775.000
778.125
781.250
784.375
787.500
790.625
793.750
796.875
800.000
806.250
812.500
818.750
825.000
831.250
837.500
843.750
850.000
856.250
862.500
868.750
875.000
881.250
887.500
893.750
900.000
906.250
912.500
918.750
925.000
931.250
937.500
943.750
950.000
956.250
962.500
968.750
975.000
981.250
987.500
993.750
1000.000
1006.250
1012.500
1018.750
1025.000
1031.250
1037.500
1043.750
1050.000
1056.250
1062.500
1068.750
1075.000
1081.250
1087.500
1093.750
1100.000
1106.250
1112.500
1118.750
1125.000
1131.250
1137.500
1143.750
1150.000
1156.250
1162.500
1168.750
1175.000
1181.250
1187.500
1193.750
1200.000
1206.250
1212.500
1218.750
1225.000
1231.250
1237.500
1243.750
1250.000
1256.250
1262.500
1268.750
1275.000
1281.250
1287.500
1293.750
1300.000
1306.250
1312.500
1318.750
1325.000
1331.250
1337.500
1343.750
1350.000
1356.250
1362.500
1368.750
1375.000
1381.250
1387.500
1393.750
1400.000
1406.250
1412.500
1418.750
1425.000
1431.250
1437.500
1443.750
1450.000
1456.250
1462.500
1468.750
1475.000
1481.250
1487.500
1493.750
1500.000
1506.250
1512.500
1518.750
1525.000
1531.250
1537.500
1543.750
1550.000
1556.250
1562.500
1568.750
1575.000
1581.250
1587.500
1593.750
1600.000
1618.750
1637.500
1656.250
1675.000
1693.750
1712.500
1731.250
1750.000
1768.750
1787.500
1806.250
1825.000
1843.750
1862.500
1881.250
1900.000
1918.750
1937.500
1956.250
1975.000
1993.750
2012.500
2031.250
2050.000
2068.750
2087.500
2106.250
2125.000
2143.750
2162.500
2181.250
2200.000
2218.750
2237.500
2256.250
2275.000
2293.750
2312.500
2331.250
2350.000
2368.750
2387.500
2406.250
2425.000
2443.750
2462.500
2481.250
2500.000
2518.750
2537.500
2556.250
2575.000
2593.750
2612.500
2631.250
2650.000
2668.750
2687.500
2706.250
2725.000
2743.750
2762.500
2781.250
2800.000
2818.750
2837.500
2856.250
2875.000
2893.750
2912.500
2931.250
2950.000
2968.750
2987.500
3006.250
3025.000
3043.750
3062.500
3081.250
3100.000
3118.750
3137.500
3156.250
3175.000
3193.750
3212.500
3231.250
3250.000
3268.750
3287.500
3306.250
3325.000
3343.750
3362.500
3381.250
3400.000
3418.750
3437.500
3456.250
3475.000
3493.750
3512.500
3531.250
3550.000
3568.750
3587.500
3606.250
3625.000
3643.750
3662.500
3681.250
3700.000
3718.750
3737.500
3756.250
3775.000
3793.750
3812.500
3831.250
3850.000
3868.750
3887.500
3906.250
3925.000
3943.750
3962.500
3981.250
"""
}

// MARK: - Scripting

// TODO: Remember to save progress to repo

func createFrequencies() -> [Float] {
  let string = createFrequenciesString()
  let lines = string.split(separator: "\n")
  
  var output: [Float] = []
  for line in lines {
    guard let converted = Float(line) else {
      fatalError("Failed to convert.")
    }
    output.append(converted)
  }
  return output
}
let frequencies = createFrequencies()

func transferFunction(ω: Float) -> Float {
  return typicalStructure(ω: ω)
}
for frequency in frequencies {
  let ω = frequency * (2 * Float.pi)
  let output = transferFunction(ω: ω)
  print(output)
}
