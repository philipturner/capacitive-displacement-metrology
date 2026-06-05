import Foundation
import PythonKit

extension ImagingWindow {
  static let imageSize: Int = 100
  static let realSpacePixelSize: Float = 0.1
  static let startPosition = SIMD2<Float>(-2, -3)
  
  static func createFakeData() -> PythonObject {
    var array = [Float](
      repeating: .zero,
      count: imageSize * imageSize)
    for rowID in 0..<imageSize {
      for columnID in 0..<imageSize {
        var output: Float = 1 + 0.3 * sin(Float(columnID))
        output *= Float(columnID) * Float(columnID)
        output += Float(rowID) * Float(rowID)
        output *= 1 + 0.2 * Float.random(in: 0..<1)
        
        let pixelID = rowID * imageSize + columnID
        array[pixelID] = output
      }
    }
    
    var ndarray = array.makeNumpyArray()
    ndarray = ndarray.reshape(imageSize, imageSize)
    return ndarray
  }
  
  static func levels(data: PythonObject) -> SIMD2<Float> {
    let minimum = Float(np.nanmin(data))!
    let maximum = Float(np.nanmax(data))!
    return SIMD2(minimum, maximum)
  }
  
  static func updateScan(image: Image) {
    let fakeData = createFakeData()
    image.imageItem.setImage(fakeData, autoLevels: false)
    
    let pixelSize = realSpacePixelSize
    let transform = QtGui.QTransform()
    transform.scale(pixelSize, pixelSize)
    transform.translate(
      startPosition[0] / pixelSize,
      startPosition[1] / pixelSize)
    image.imageItem.setTransform(transform)
    
    let levels = Self.levels(data: fakeData)
    image.colorBar.setLevels(
      low: levels[0] + (levels[1] - levels[0]) * 0.00,
      high: levels[0] + (levels[1] - levels[0]) * 0.75)
  }
  
  static func updateFourier(image: Image) {
    let start = Date().timeIntervalSince1970
    
    let fakeData = createFakeData()
    let f_transform = np.fft.fft2(fakeData)
    let f_shifted = np.fft.fftshift(f_transform)
    let output = 20 * np.log10(np.abs(f_shifted))
    image.imageItem.setImage(output, autoLevels: false)
    
    let fourierSpacePixelSize = (1 / realSpacePixelSize) / Float(imageSize)
    let offset = -Float(imageSize) / 2 * fourierSpacePixelSize
    
    let pixelSize = fourierSpacePixelSize
    let startPosition = SIMD2(repeating: offset)
    
    let transform = QtGui.QTransform()
    transform.scale(pixelSize, pixelSize)
    transform.translate(
      startPosition[0] / pixelSize,
      startPosition[1] / pixelSize)
    image.imageItem.setTransform(transform)
    
    let levels = Self.levels(data: output)
    image.colorBar.setLevels(
      low: levels[0] + (levels[1] - levels[0]) * 0.50,
      high: levels[0] + (levels[1] - levels[0]) * 1.00)
    
    let end = Date().timeIntervalSince1970
    print("time:", Float(end - start) * 1000)
  }
}
