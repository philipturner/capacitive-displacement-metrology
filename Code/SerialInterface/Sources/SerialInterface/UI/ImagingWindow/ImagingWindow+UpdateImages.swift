import PythonKit

extension ImagingWindow {
  func resetImages() {
    for imageID in 0..<5 {
      let emptyArray = [Float](repeating: 0, count: imagingState.settings.pixelsPerImage)
      
      var ndarray = [data].makeNumpyArray()
      //    ndarray = ndarray.reshape(rowCount, columnCount)
    }
  }
  
//  static func castToNumpy(_ data: [Float]) -> PythonObject {
//    guard data.count % columnCount == 0 else {
//      fatalError("Image was not divisible by column count.")
//    }
//    let rowCount = data.count / columnCount
//    
//    var ndarray = data.makeNumpyArray()
//    ndarray = ndarray.reshape(rowCount, columnCount)
//    return ndarray
//  }
  
  static func fourierTransform(_ image: PythonObject) -> PythonObject {
    func safeLog10(_ input: PythonObject) -> PythonObject {
      let mask = np.greater(input, Float(0))
      
      // Mask such that masked out values are -1000 after multiplying by 20.
      let output = np.zeros_like(input, dtype: np.float32) - 1000 / 20
      np.log10(input, where: mask, out: output)
      return output
    }
    
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
  // Find a more elegant way to incorporate this
  #if false
  func emptyImage() -> [SIMD2<Float>]? {
    if plotDataValid {
      return nil
    }
    
    let pixelsPerImage = state.settings.pixelsPerImage
    let pixel = SIMD2<Float>(0, 0)
    return Array(repeating: pixel, count: pixelsPerImage)
  }
  #endif
  
  func updateScanImages() {
    for rowID in 0..<2 {
      for columnID in 0..<2 {
        
        
//        func createSourceData() -> [SIMD2<Float>]? {
//          if state.settings.mode == .dualVideo {
//            return state.pendingImages[columnID]
//          } else {
//            if columnID == 0 {
//              let finishedRowCount = state.pixelTracker.finishedRowCount
//              if finishedRowCount == 0 {
//                return nil
//              } else {
//                let pixelCount = finishedRowCount * state.settings.resolution
//                let dataBuffer = state.pixelTracker.dataBuffer
//                let startChunk = Array(dataBuffer[0..<pixelCount])
//                return startChunk
//              }
//            } else {
//              return state.pendingImages[0]
//            }
//          }
//        }
        
//        let sourceData = createSourceData() ?? emptyImage()
//        guard let sourceData else {
//          continue
//        }
        
        func createSourceData2() -> [SIMD2<Float>] {
          var output = sourceData
          for i in output.indices {
            output[i][0] *= 1e12
          }
          return output
        }
        let sourceData2 = createSourceData2()
        let partialData = sourceData2.map { $0[rowID] }
        let filledData = fillRemainingRows(sourceData2).map { $0[rowID] }
        let image = scanImages[rowID][columnID]
        
        do {
          let filledDataNumpy = Self.castToNumpy(
            filledData, columnCount: state.settings.resolution)
          image.imageItem.setImage(filledDataNumpy, autoLevels: false)
        }
        
        do {
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
        }
        
        // if empty image, all four stats should be 0: avg, stddev, min, max
        func createLevels() -> SIMD2<Float> {
          let partialDataNumpy = Self.castToNumpy(
            partialData, columnCount: state.settings.resolution)
          
          if rowID == 0 {
            let mean = Float(np.mean(partialDataNumpy))!
            let stddev = Float(np.std(partialDataNumpy))!
            return SIMD2<Float>(
              mean - stddev * 3,
              mean + stddev * 3)
          } else {
            let levels = Self.levels(data: partialDataNumpy)
            let dz = levels[1] - levels[0]
            if dz < 0.1 {
              let center = levels.sum() / 2
              return SIMD2(center - 0.05, center + 0.05)
            } else {
              return levels
            }
          }
        }
        
        let levels = createLevels()
        image.colorBar.setLevels(
          low: levels[0],
          high: levels[1])
      }
    }
  }
  
  func updateFourierImageVisibility() {
    if state.settings.mode == .dualVideo {
      fourierImage.plot.hide()
      labels[3].hide()
    } else {
      fourierImage.plot.show()
      labels[3].show()
    }
  }
  
  
  
  func updateFourierImage() {
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
    image.imageItem.setTransform(settings.fourierSpaceTransform())
    
    let minimum = Float(np.nanmin(data))!
    let maximum = Float(np.nanmax(data))!
    return SIMD2(minimum, maximum)
    
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
