import PythonKit

struct ImagingSettings {
  var mode: ImagingMode
  var resolution: Int
  var size: Float
  var centers: [SIMD2<Float>]
  var setpointCurrent: Float
  
  init(values: [Float]) {
    guard values.count == 8 else {
      fatalError("Invalid number of values.")
    }
    
    guard let rawValue = UInt8(exactly: values[0]),
          let mode = ImagingMode(rawValue: rawValue) else {
      fatalError("Invalid mode.")
    }
    self.mode = mode
    
    guard let resolution = Int(exactly: values[1]),
          resolution > 0,
          resolution % 2 == 0 else {
      fatalError("Invalid resolution.")
    }
    self.resolution = resolution
    
    self.size = values[2]
    
    self.centers = [
      SIMD2(values[3], values[4]),
      SIMD2(values[5], values[6]),
    ]
    
    self.setpointCurrent = values[7]
  }
  
  var pixelsPerImage: Int {
    resolution * resolution
  }
  
  func currentImageCenter(imageID: Int) -> SIMD2<Float> {
    if mode == .dualVideo, imageID % 2 == 1 {
      return centers[1]
    } else {
      return centers[0]
    }
  }
  
  func expectedPosition(pixelID: Int, imageID: Int) -> SIMD2<Float> {
    let rowID = pixelID / resolution
    let columnID = pixelID % resolution
    
    var position = SIMD2(Float(columnID), Float(rowID))
    position = (position + 0.5) * size / Float(resolution)
    position -= size / 2
    position += currentImageCenter(imageID: imageID)
    return position
  }
}

extension ImagingSettings {
  func realSpaceTransform(videoChannelID: Int) -> PythonObject {
    guard videoChannelID == 0 || videoChannelID == 1 else {
      fatalError("This should never happen.")
    }
    
    let pixelSize = size / Float(resolution)
    
    var position: SIMD2<Float> = .zero
    position -= size / 2
    position += currentImageCenter(imageID: videoChannelID)
    
    let transform = QtGui.QTransform()
    transform.scale(pixelSize, pixelSize)
    transform.translate(
      position[0] / pixelSize,
      position[1] / pixelSize)
    return transform
  }
  
  func fourierSpaceTransform() -> PythonObject {
    let realSpacePixelSize = size / Float(resolution)
    let pixelSize = (1 / realSpacePixelSize) / Float(resolution)
    
    let offset = -Float(resolution) / 2 * pixelSize
    let position = SIMD2(repeating: offset)
    
    let transform = QtGui.QTransform()
    transform.scale(pixelSize, pixelSize)
    transform.translate(
      position[0] / pixelSize,
      position[1] / pixelSize)
    return transform
  }
}
