import PythonKit

struct ImagingSettings {
  var mode: ImagingMode
  var trueResolutionMajor: Int
  var resolutionMajor: Int
  var resolutionMinor: Int
  var pixelDimension: Float
  
  var majorAxis: Int
  var centers: [SIMD2<Float>]
  
  var polynomialPeakTime: Int
  var electronicTimeLag: Int
  var creepSettlingTime: Int
  var imageTime: Int
  var feedbackTimeConstant: Int
  
  var setpointCurrent: Float
  
  init(settingsLines: [LineParser.Line]) {
    guard settingsLines.count == 4 else {
      fatalError(
        "Invalid number of imaging settings lines: \(settingsLines.count)")
    }
    
    func createMode() -> ImagingMode {
      let value = UInt8(settingsLines[0].values[0])
      guard let mode = ImagingMode(rawValue: value) else {
        fatalError("Invalid mode.")
      }
      return mode
    }
    self.mode = createMode()
    self.trueResolutionMajor = Int(settingsLines[0].values[1])
    self.resolutionMajor = Int(settingsLines[0].values[2])
    self.resolutionMinor = Int(settingsLines[0].values[3])
    self.pixelDimension = settingsLines[0].values[4]
    
    func createCenters() -> [SIMD2<Float>] {
      var output: [SIMD2<Float>] = []
      for centerID in 0..<2 {
        let laneOffset = 1 + centerID * 2
        
        let x = settingsLines[1].values[laneOffset + 0]
        let y = settingsLines[1].values[laneOffset + 1]
        let center = SIMD2(x, y)
        output.append(center)
      }
      return output
    }
    self.majorAxis = Int(settingsLines[1].values[0])
    self.centers = createCenters()
    
    func convertTime(_ milliseconds: Float) -> Int {
      var microseconds = (milliseconds * 1000)
      microseconds.round(.toNearestOrEven)
      return Int(microseconds)
    }
    self.polynomialPeakTime = Int(settingsLines[2].values[0])
    self.electronicTimeLag = Int(settingsLines[2].values[1])
    self.creepSettlingTime = convertTime(settingsLines[2].values[2])
    self.imageTime = convertTime(settingsLines[2].values[3])
    self.feedbackTimeConstant = convertTime(settingsLines[2].values[4])
    
    self.setpointCurrent = settingsLines[3].values[0]
  }
  
  var pixelsPerImage: Int {
    resolutionMajor * resolutionMinor
  }
  
  var maxResolution: Int {
    max(resolutionMajor, resolutionMinor)
  }
  
  func center(channelID: Int) -> SIMD2<Float> {
    guard channelID >= 0, channelID < 2 else {
      fatalError("Invalid channel ID.")
    }
    
    if mode == .dualVideo {
      return centers[channelID]
    } else {
      return centers[0]
    }
  }
  
  func expectedPosition(pixelID: Int, imageID: Int) -> SIMD2<Float> {
    let rowID = pixelID / resolutionMajor
    let columnID = pixelID % resolutionMajor
    let resolutionVector = SIMD2(
      Float(resolutionMajor),
      Float(resolutionMinor))
    
    var position = SIMD2(Float(columnID), Float(rowID))
    position += 0.5
    position *= pixelDimension
    position -= 0.5 * resolutionVector * pixelDimension
    
    if majorAxis == 1 {
      position = SIMD2(position.y, position.x)
    }
    
    position += center(channelID: imageID % 2)
    return position
  }
}

extension ImagingSettings {
  // Probably need to pad with zeroes before entering, so that rectangular
  // images have the same spatial footprint as square images.
  func realSpaceTransform(channelID: Int) -> PythonObject {
    var offset: SIMD2<Float> = .zero
    offset -= 0.5 * Float(maxResolution) * pixelDimension
    offset += center(channelID: channelID)
    offset /= pixelDimension
    
    let transform = QtGui.QTransform()
    transform.scale(pixelDimension, pixelDimension)
    transform.translate(offset.x, offset.y)
    
    return transform
  }
  
  func fourierSpaceTransform() -> PythonObject {
    if ImagingWindow.useZeroPaddedFourierImage {
      let resolution = max(resolutionMajor, resolutionMinor)
      let fourierPixelDimension = (1 / pixelDimension) / Float(resolution)
      
      var offset: SIMD2<Float> = .zero
      offset -= 0.5 * Float(resolution) * fourierPixelDimension
      offset /= fourierPixelDimension
      
      let transform = QtGui.QTransform()
      transform.scale(fourierPixelDimension, fourierPixelDimension)
      transform.translate(offset.x, offset.y)
      return transform
    } else {
      func createResolutionVector() -> SIMD2<Float> {
        if majorAxis == 0 {
          return SIMD2(
            Float(resolutionMajor),
            Float(resolutionMinor))
        } else {
          return SIMD2(
            Float(resolutionMinor),
            Float(resolutionMajor))
        }
      }
      
      let resolutionVector = createResolutionVector()
      let fourierPixelDimension = (1 / pixelDimension) / resolutionVector
      
      var offset: SIMD2<Float> = .zero
      offset -= 0.5 * resolutionVector * fourierPixelDimension
      offset /= fourierPixelDimension
      
      let transform = QtGui.QTransform()
      transform.scale(fourierPixelDimension.x, fourierPixelDimension.y)
      transform.translate(offset.x, offset.y)
      return transform
    }
  }
}
