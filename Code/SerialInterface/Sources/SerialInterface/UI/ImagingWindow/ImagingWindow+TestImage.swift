import Foundation
import PythonKit

extension ImagingWindow {
  private static let testImageSize: Int = 100
  private static let testRealSpacePixelSize: Float = 0.1
  private static let testStartPosition = SIMD2<Float>(-2, -3)
  
  static func createTestData() -> PythonObject {
    var array = [Float](
      repeating: .zero,
      count: testImageSize * testImageSize)
    for rowID in 0..<testImageSize {
      for columnID in 0..<testImageSize {
        var output: Float = 1 + 0.3 * sin(Float(columnID))
        output *= Float(columnID) * Float(columnID)
        output += Float(rowID) * Float(rowID)
        output *= 1 + 0.2 * Float.random(in: 0..<1)
        
        let pixelID = rowID * testImageSize + columnID
        array[pixelID] = output
      }
    }
    
    var ndarray = array.makeNumpyArray()
    ndarray = ndarray.reshape(testImageSize, testImageSize)
    return ndarray
  }
  
  static func levels(data: PythonObject) -> SIMD2<Float> {
    let minimum = Float(np.nanmin(data))!
    let maximum = Float(np.nanmax(data))!
    return SIMD2(minimum, maximum)
  }
  
  static func updateScanImageWithTest(image: Image) {
    let testData = createTestData()
    image.imageItem.setImage(testData, autoLevels: false)
    
    let pixelSize = testRealSpacePixelSize
    let transform = QtGui.QTransform()
    transform.scale(pixelSize, pixelSize)
    transform.translate(
      testStartPosition[0] / pixelSize,
      testStartPosition[1] / pixelSize)
    image.imageItem.setTransform(transform)
    
    let levels = Self.levels(data: testData)
    image.colorBar.setLevels(
      low: levels[0] + (levels[1] - levels[0]) * 0.00,
      high: levels[0] + (levels[1] - levels[0]) * 0.75)
  }
  
  static func updateFourierImageWithTest(image: Image) {
    let testData = createTestData()
    let f_transform = np.fft.fft2(testData)
    let f_shifted = np.fft.fftshift(f_transform)
    let output = 20 * np.log10(np.abs(f_shifted))
    image.imageItem.setImage(output, autoLevels: false)
    
    let fourierSpacePixelSize = (1 / testRealSpacePixelSize) / Float(testImageSize)
    let offset = -Float(testImageSize) / 2 * fourierSpacePixelSize
    
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
  }
}
