import PythonKit

extension ImagingWindow {
  static func castToNumpy(_ data: [Float]) -> PythonObject {
    let sizeFloat = Double(data.count).squareRoot()
    guard let sizeInt = Int(exactly: sizeFloat) else {
      fatalError("Image was not square.")
    }
    
    var ndarray = data.makeNumpyArray()
    ndarray = ndarray.reshape(sizeInt, sizeInt)
    return ndarray
  }
  
  static func levels(data: PythonObject) -> SIMD2<Float> {
    let minimum = Float(np.nanmin(data))!
    let maximum = Float(np.nanmax(data))!
    return SIMD2(minimum, maximum)
  }
  
  private static func safeLog10(_ input: PythonObject) -> PythonObject {
    let output = np.zeros_like(input, dtype: np.float32) - 1000 / 20
    let mask = np.greater(input, Float(0))
    np.log10(input, where: mask, out: output)
    return output
  }
  
  static func fourierTransform(_ image: PythonObject) -> PythonObject {
    var output = image
    output = np.fft.fft2(output)
    output = np.fft.fftshift(output)
    output = np.abs(output)
    output = safeLog10(output)
    output = 20 * output
    return output
  }
  
  // Returns a replacement image only when the image views need to be reset.
  func emptyImage() -> [SIMD2<Float>]? {
    if plotDataValid {
      return nil
    }
    
    let pixelsPerImage = state.settings.pixelsPerImage
    let pixel = SIMD2<Float>(
      state.settings.setpointCurrent, 0)
    return Array(repeating: pixel, count: pixelsPerImage)
  }
  
  func updateScanImages() {
    for rowID in 0..<2 {
      for columnID in 0..<2 {
        func createSourceData() -> [SIMD2<Float>]? {
          if state.settings.mode == .dualVideo {
            return state.pendingImages[columnID]
          } else {
            if columnID == 0 {
              let finishedRowCount = state.pixelTracker.finishedRowCount
              if finishedRowCount == 0 {
                return nil
              } else {
                let pixelCount = finishedRowCount * state.settings.resolution
                let dataBuffer = state.pixelTracker.dataBuffer
                return Array(dataBuffer[0..<pixelCount])
              }
            } else {
              return state.pendingImages[0]
            }
          }
        }
        
        let sourceData = createSourceData() ?? emptyImage()
        guard let sourceData else {
          continue
        }
        let data = sourceData.map { $0[rowID] }
        let finalData = Self.castToNumpy(data)
        
        let image = scanImages[rowID][columnID]
        
        func createVideoChannelID() -> Int {
          if state.settings.mode == .dualVideo {
            return columnID
          } else {
            return 1
          }
        }
        let videoChannelID = createVideoChannelID()
      }
    }
  }
  
  func updateFourierImage() {
    if state.settings.mode == .dualVideo {
      fourierImage.plot.hide()
      return
    } else {
      fourierImage.plot.show()
    }
    
    let sourceData = state.pendingImages[0] ?? emptyImage()
    guard let sourceData else {
      return
    }
    let data = sourceData.map { $0[0] }
    let dataNumpy = Self.castToNumpy(data)
    let finalData = Self.fourierTransform(dataNumpy)
    
    let image = fourierImage
    
    // high: data max
    // low: data max - 100 dB
  }
}
