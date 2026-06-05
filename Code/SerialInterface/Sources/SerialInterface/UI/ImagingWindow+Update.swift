import Foundation
import PythonKit

extension ImagingWindow {
  static let imageSize: Int = 100
  
  static func createFakeData() -> PythonObject {
    let arrayDimension = PythonObject(
      tupleOf: Int(imageSize), Int(imageSize))
    var data = np.zeros(shape: arrayDimension, dtype: np.float32)
    for i in 0..<imageSize {
      for j in 0..<imageSize {
        var output: Float = 1 + 0.3 * sin(Float(i))
        output *= Float(i) * Float(i)
        output += Float(j) * Float(j)
        output *= 1 + 0.2 * Float.random(in: 0..<1)
        
        data[j, i] = PythonObject(output)
      }
    }
    return data
  }
  
  static func levels(array: PythonObject) -> SIMD2<Float> {
    var minimum: Float = .greatestFiniteMagnitude
    var maximum: Float = -.greatestFiniteMagnitude
    for i in 0..<imageSize {
      for j in 0..<imageSize {
        let value = Float(array[j, i])
        guard let value else {
          fatalError("Could not decode FP32 from Python.")
        }
        
        minimum = min(minimum, value)
        maximum = max(maximum, value)
      }
    }
    return SIMD2(minimum, maximum)
  }
  
  static func updateScan(image: Image) {
    let fakeData = createFakeData()
    image.imageItem.setImage(fakeData, autoLevels: false)
    
    let pixelSize: Float = 0.1
    let startPosition = SIMD2<Float>(-2, -3)
    let transform = QtGui.QTransform()
    transform.scale(pixelSize, pixelSize)
    transform.translate(
      startPosition[0] / pixelSize,
      startPosition[1] / pixelSize)
    image.imageItem.setTransform(transform)
    
    let levels = Self.levels(array: fakeData)
    image.colorBar.setLevels(
      low: levels[0] + (levels[1] - levels[0]) * 0.00,
      high: levels[0] + (levels[1] - levels[0]) * 0.75)
  }
  
  static func updateFourier(image: Image) {
    let fakeData = createFakeData()
    image.imageItem.setImage(_fakeData, autoLevels: false)
    
    let pixelSize: Float = 0.1
    let startPosition = SIMD2<Float>(-2, -3)
    let transform = QtGui.QTransform()
    transform.scale(pixelSize, pixelSize)
    transform.translate(
      startPosition[0] / pixelSize,
      startPosition[1] / pixelSize)
    image.imageItem.setTransform(transform)
    
    let levels = Self.levels(array: _fakeData)
    image.colorBar.setLevels(
      low: levels[0] + (levels[1] - levels[0]) * 0.25,
      high: levels[0] + (levels[1] - levels[0]) * 0.75)
  }
}
