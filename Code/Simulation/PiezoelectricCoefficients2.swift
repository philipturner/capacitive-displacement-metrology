import func Foundation.cos
import func Foundation.sin

// Important clarification:
// - rotated basis = local coordinate space of the wafer
// - original basis = x, y, z basis of the crystal boule before cutting

// MARK: - Math Utilities

// Data type for a 3x3 matrix.
struct Matrix {
  var row1: SIMD3<Float> = .zero
  var row2: SIMD3<Float> = .zero
  var row3: SIMD3<Float> = .zero
  
  static func * (lhs: Matrix, rhs: SIMD3<Float>) -> SIMD3<Float> {
    var output: SIMD3<Float> = .zero
    output[0] = (lhs.row1 * rhs).sum()
    output[1] = (lhs.row2 * rhs).sum()
    output[2] = (lhs.row3 * rhs).sum()
    return output
  }
  
  static func * (lhs: Matrix, rhs: Float) -> Matrix {
    var output = lhs
    output.row1 *= rhs
    output.row2 *= rhs
    output.row3 *= rhs
    return output
  }
  
  static func + (lhs: Matrix, rhs: Matrix) -> Matrix {
    var output = lhs
    output.row1 += rhs.row1
    output.row2 += rhs.row2
    output.row3 += rhs.row3
    return output
  }
}

// ambiguous:
// - coordinate space of the inputs and outputs
// - polarity of the angle rotation
func rotationMatrix(angleRadians: Float) -> Matrix {
  var output = Matrix()
  output.row1 = SIMD3(1, 0, 0)
  output.row2 = SIMD3(0, cos(-angleRadians), sin(-angleRadians))
  output.row3 = SIMD3(0, -sin(-angleRadians), cos(-angleRadians))
  return output
}

// MARK: - Material Properties

// The four numbers that generate all piezo constants. Units: m/V
struct PiezoCoefficientsMatrixDescriptor {
  var d15: Float = .zero
  var d22: Float = .zero
  var d31: Float = .zero
  var d33: Float = .zero
}

// 3 x 6 matrix containing all piezoelectric coefficients for a crystal in the
// hexagonal '3m' family. Units: m/V
struct PiezoCoefficientsMatrix {
  // 1x6 row vector, for all coefficients related to E_x.
  var electricFieldX: [Float]
  
  // 1x6 row vector, for all coefficients related to E_y.
  var electricFieldY: [Float]
  
  // 1x6 row vector, for all coefficients related to E_z.
  var electricFieldZ: [Float]
  
  init(descriptor: PiezoCoefficientsMatrixDescriptor) {
    self.electricFieldX = [
      0, 0, 0, 0, descriptor.d15, -2 * descriptor.d22
    ]
    self.electricFieldY = [
      -descriptor.d22, descriptor.d22, 0, descriptor.d15, 0, 0
    ]
    self.electricFieldZ = [
      descriptor.d31, descriptor.d31, descriptor.d33, 0, 0, 0
    ]
  }
}

// 3 x 3 x 3 tensor, containing the piezoelectric coefficients in tensor form.
struct PiezoCoefficientsTensor {
  // 3 x 3 matrix, for all coefficients related to E_x.
  var electricFieldX: Matrix
  
  // 3 x 3 matrix, for all coefficients related to E_y.
  var electricFieldY: Matrix
  
  // 3 x 3 matrix, for all coefficients related to E_z.
  var electricFieldZ: Matrix
  
  init(matrix: PiezoCoefficientsMatrix) {
    func matrixFromRowVector(_ rowVector: [Float]) -> Matrix {
      var output = Matrix()
      output.row1 = SIMD3(
        rowVector[1 - 1], rowVector[6 - 1] / 2, rowVector[5 - 1] / 2)
      output.row2 = SIMD3(
        rowVector[6 - 1] / 2, rowVector[2 - 1], rowVector[4 - 1] / 2)
      output.row3 = SIMD3(
        rowVector[5 - 1] / 2, rowVector[4 - 1] / 2, rowVector[3 - 1])
      return output
    }
    
    self.electricFieldX = matrixFromRowVector(
      matrix.electricFieldX)
    self.electricFieldY = matrixFromRowVector(
      matrix.electricFieldY)
    self.electricFieldZ = matrixFromRowVector(
      matrix.electricFieldZ)
  }
  
  func strainMatrix(electricField: SIMD3<Float>) -> Matrix {
    var output = Matrix()
    output = output + electricFieldX * electricField[0]
    output = output + electricFieldY * electricField[1]
    output = output + electricFieldZ * electricField[2]
    return output
  }
}

// MARK: - Setup

var piezoMatrixDesc = PiezoCoefficientsMatrixDescriptor()
piezoMatrixDesc.d15 = 68e-12
piezoMatrixDesc.d22 = 21e-12
piezoMatrixDesc.d31 = -1e-12
piezoMatrixDesc.d33 = 6e-12

let piezoMatrix = PiezoCoefficientsMatrix(descriptor: piezoMatrixDesc)
let piezoTensor = PiezoCoefficientsTensor(matrix: piezoMatrix)

// The angle the coordinate system rotates about the X-axis.
guard CommandLine.arguments.count == 2 else {
  fatalError("Enter rotation angle as argument to script.")
}
let angleArgument = CommandLine.arguments[1]
guard let angleDegrees = Float(angleArgument) else {
  fatalError("Enter rotation angle as argument to script.")
}
let angleRadians: Float = angleDegrees * .pi / 180

// The electric field normal to the surface isn't affected by the rotation.
let electricFieldRot = SIMD3<Float>(850 / 0.5e-3, 0, 0)
let electricFieldOrig = rotationMatrix(angleRadians: angleRadians) * electricFieldRot

// Strain matrix in the coordinate system of the true crystallographic axes.
let strainMatrix = piezoTensor.strainMatrix(electricField: electricFieldOrig)

// Specify the device dimensions.
let dimensionX: Float = 0.5e-3
let dimensionY: Float = 5e-3
let dimensionZ: Float = 5e-3

// MARK: - Solving for Displacement

func displacement(xRot: SIMD3<Float>) -> SIMD3<Float> {
  let rotation = rotationMatrix(angleRadians: angleRadians)
  let xOrig = rotation * xRot
  let uOrig = strainMatrix * xOrig
  
  let rotationInv = rotationMatrix(angleRadians: -angleRadians)
  let uRot = rotationInv * uOrig
  return uRot
}

// List the points to query.
var positions: [SIMD3<Float>] = []
positions.append(SIMD3(0, 0, 0))
positions.append(SIMD3(0, 0, dimensionZ))
positions.append(SIMD3(0, dimensionY, 0))
positions.append(SIMD3(0, dimensionY, dimensionZ))
positions.append(SIMD3(dimensionX, 0, 0))
positions.append(SIMD3(dimensionX, 0, dimensionZ))
positions.append(SIMD3(dimensionX, dimensionY, 0))
positions.append(SIMD3(dimensionX, dimensionY, dimensionZ))

// Calculate the displacement at each point.
var displacements: [SIMD3<Float>] = []
for position in positions {
  let xRot = position
  let uRot = displacement(xRot: xRot)
  displacements.append(uRot)
  
  #if false
  print()
  print("x_rot:", xRot)
  print("u_rot:", uRot)
  #endif
}

// MARK: - Solving for Piezo Constant

print()
print("// \(Int(angleDegrees))°")
let E1 = electricFieldRot[1 - 1]

do {
  let du = displacements[4] - displacements[0]
  let dx = positions[4] - positions[0]
  let piezoConstant = du / dx[1 - 1] / E1
  print("//  ∂(∂u/∂x1)/∂E1:", piezoConstant * 1e12, "pm/V")
}

do {
  let du = displacements[2] - displacements[0]
  let dx = positions[2] - positions[0]
  let piezoConstant = du / dx[2 - 1] / E1
  print("//  ∂(∂u/∂x2)/∂E1:", piezoConstant * 1e12, "pm/V")
}

do {
  let du = displacements[1] - displacements[0]
  let dx = positions[1] - positions[0]
  let piezoConstant = du / dx[3 - 1] / E1
  print("//  ∂(∂u/∂x3)/∂E1:", piezoConstant * 1e12, "pm/V")
}

// MARK: - Displacement in Nanometers

// Converts a displacement in SI units to nanometers.
func formatInNm(_ displacement: SIMD3<Float>) -> String {
  var componentStrings: [String] = []
  for laneID in 0..<3 {
    let componentNumberInM = displacement[laneID]
    let componentNumberInNm = componentNumberInM / 1e-9
    let componentString = String(format: "%.1f", componentNumberInNm)
    componentStrings.append(componentString)
  }
  
  var output: String = "["
  output += componentStrings[0]
  output += ", "
  output += componentStrings[1]
  output += ", "
  output += componentStrings[2]
  output += "]"
  return output
}

print()
print("// \(Int(angleDegrees))°")
print("//  u (x-axis): \(formatInNm(displacements[4])) nm")
print("//  u (y-axis): \(formatInNm(displacements[2])) nm")
print("//  u (z-axis): \(formatInNm(displacements[1])) nm")

// MARK: - Improving Interpretation of Output

do {
  var xAxis = displacements[4]
  var yAxis = displacements[2]
  var zAxis = displacements[1]
  
  xAxis.y += yAxis.x * dimensionX / dimensionY
  xAxis.z += zAxis.x * dimensionX / dimensionZ
  yAxis.x = 0
  zAxis.x = 0
  
  print()
  print("// \(Int(angleDegrees))°")
  print("//  u (x-axis): \(formatInNm(xAxis)) nm")
  print("//  u (y-axis): \(formatInNm(yAxis)) nm")
  print("//  u (z-axis): \(formatInNm(zAxis)) nm")
}
