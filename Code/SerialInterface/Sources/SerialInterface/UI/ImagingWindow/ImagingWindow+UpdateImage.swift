import PythonKit

extension ImagingWindow {
  static func castToNumpy(_ data: [Float], columnCount: Int) -> PythonObject {
    guard data.count % columnCount == 0 else {
      fatalError("Image was not divisible by column count.")
    }
    let rowCount = data.count / columnCount
    
    var ndarray = data.makeNumpyArray()
    ndarray = ndarray.reshape(rowCount, columnCount)
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
    output -= np.mean(output)
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
    let pixel = SIMD2<Float>(0, 0)
    return Array(repeating: pixel, count: pixelsPerImage)
  }
  
  func fillRemainingRows(_ image: [SIMD2<Float>]) -> [SIMD2<Float>] {
    if image.count == state.settings.pixelsPerImage {
      return image
    }
    
    var minimumZ: Float = .zero
    for pixel in image {
      let z = pixel[1]
      minimumZ = min(minimumZ, z)

    }
    
    let fillerPixel = SIMD2<Float>(0, minimumZ)
    let remainingPixelCount = state.settings.pixelsPerImage - image.count
    let fillerChunk = Array(
      repeating: fillerPixel,
      count: remainingPixelCount)
    return image + fillerChunk
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
                let startChunk = Array(dataBuffer[0..<pixelCount])
                return fillRemainingRows(startChunk)
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
        var data = sourceData.map { $0[rowID] }
        if rowID == 0 {
          for i in 0..<data.count {
            data[i] *= 1e12
          }
        }
        
        let finalData = Self.castToNumpy(
          data, columnCount: state.settings.resolution)
        
        let image = scanImages[rowID][columnID]
        image.imageItem.setImage(finalData, autoLevels: false)
        
        func createVideoChannelID() -> Int {
          if state.settings.mode == .dualVideo {
            return columnID
          } else {
            return 1
          }
        }
        let videoChannelID = createVideoChannelID()
        let transform = state.settings.realSpaceTransform(
          videoChannelID: videoChannelID)
        image.imageItem.setTransform(transform)
        
        // Eventually, we might migrate to a different heuristic:
        // mask out the outliers (current spikes) outside 0 < I < 2 * setpoint
        // take the average and standard deviation
        // plot out to +/-3 sigma
        if rowID == 0 {
          let levels = SIMD2<Float>(
            0.7 * state.settings.setpointCurrent * 1e12,
            1.3 * state.settings.setpointCurrent * 1e12)
          image.colorBar.setLevels(
            low: levels[0],
            high: levels[1])
        } else {
          let levels = Self.levels(data: finalData)
          image.colorBar.setLevels(
            low: levels[0],
            high: levels[1])
        }
      }
    }
  }
  
  func updateFourierImage() {
    if state.settings.mode == .dualVideo {
      fourierImage.plot.hide()
      labels[3].hide()
      return
    } else {
      fourierImage.plot.show()
      labels[3].show()
    }
    
    let sourceData = state.pendingImages[0] ?? emptyImage()
    guard let sourceData else {
      return
    }
    var data = sourceData.map { $0[0] }
    for i in 0..<data.count {
      data[i] /= state.settings.setpointCurrent
    }
    
    let dataNumpy = Self.castToNumpy(
      data, columnCount: state.settings.resolution)
    let finalData = Self.fourierTransform(dataNumpy)
    
    let image = fourierImage
    image.imageItem.setImage(finalData, autoLevels: false)
    
    let transform = state.settings.fourierSpaceTransform()
    image.imageItem.setTransform(transform)
    
    let levels = Self.levels(data: finalData)
    if state.pendingImages[0] == nil {
      image.colorBar.setLevels(
        low: levels[1],
        high: levels[1] + 40)
    } else {
      image.colorBar.setLevels(
        low: levels[1] - 40,
        high: levels[1])
    }
  }
}
