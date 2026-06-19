import Foundation
import PythonKit

extension ImagingWindow {
  func castToNumpy(_ data: [Float]) -> PythonObject {
    guard data.count == settings.pixelsPerImage else {
      fatalError("Incorrectly sized data array.")
    }
    
    var ndarray = data.makeNumpyArray()
    ndarray = ndarray.reshape(settings.resolution, settings.resolution)
    return ndarray
  }
  
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
}

extension ImagingWindow {
  func updateFourierImageVisibility() {
    if settings.mode == .dualVideo {
      fourierImagePlots[0].plot.hide()
      fourierImagePlots[1].plot.hide()
      labels[3].hide()
    } else {
      fourierImagePlots[0].plot.hide()
      fourierImagePlots[1].plot.show()
      labels[3].show()
    }
  }
  
  func updateGridVisibility() {
    for rowID in 0..<2 {
      for columnID in 0..<2 {
        let imagePlot = scanImagePlots[rowID][columnID]
        let gridItem = imagePlot.gridItem!
        
        if settings.mode == .dualVideo {
          gridItem.hide()
        } else if Self.auxiliaryImageType == .incoming {
          gridItem.hide()
        } else {
          if columnID == 0 {
            gridItem.show()
          } else {
            gridItem.hide()
          }
        }
      }
    }
  }
  
  func resetImages() {
    resetScanImage(columnID: 0)
    resetScanImage(columnID: 1)
    resetFourierImage(columnID: 0)
    resetFourierImage(columnID: 1)
  }
  
  func resetScanImage(columnID: Int) {
    for rowID in 0..<2 {
      let emptyData = [Float](repeating: 0, count: settings.pixelsPerImage)
      let dataNumpy = castToNumpy(emptyData)
      let imagePlot = scanImagePlots[rowID][columnID]
      imagePlot.imageItem.setImage(dataNumpy, autoLevels: false)
      
      let transform = settings.realSpaceTransform(channelID: columnID)
      imagePlot.imageItem.setTransform(transform)
      
      imagePlot.colorBar.setLevels(
        low: Float(0),
        high: Float(1))
    }
  }
  
  func resetFourierImage(columnID: Int) {
    let emptyData = [Float](repeating: 0, count: settings.pixelsPerImage)
    let dataNumpy = castToNumpy(emptyData)
    let imagePlot = fourierImagePlots[columnID]
    imagePlot.imageItem.setImage(dataNumpy, autoLevels: false)
    
    let transform = settings.fourierSpaceTransform()
    imagePlot.imageItem.setTransform(transform)
    
    imagePlot.colorBar.setLevels(
      low: Float(0),
      high: Float(1))
  }
}

extension ImagingWindow {
  func updateImages() {
    if settings.mode == .dualVideo {
      for channelID in 0..<2 {
        let image = imageHistory.pendingImages[channelID]
        guard let image else {
          continue
        }
        
        let (even, odd) = image.split()
        func getSplitImage() -> PixelTracker {
          switch Self.dualImageType {
          case .allLines:
            return image
          case .even:
            return even
          case .odd:
            return odd
          }
        }
        setScanImagePair(getSplitImage(), columnID: channelID)
      }
    } else {
      setAuxiliaryImage()
      setScanImagePair(imageHistory.pendingImages[0], columnID: 1)
      setFourierImage(imageHistory.pendingImages[0], columnID: 1)
    }
  }
  
  func setAuxiliaryImage() {
    if Self.auxiliaryImageType == .incoming {
      if let pendingImage = imageHistory.pendingImages[0] {
        state.lastImageStatistics = pendingImage.statistics
      }
      
      func shouldOverwriteIncomingImage() -> Bool {
        let oldImage = imageHistory.pendingImages[0]
        guard oldImage != nil else {
          return false
        }
        
        let newImage = imageHistory.pixelTracker
        if newImage.statistics == nil {
          return true
        } else {
          return false
        }
      }
      
      if shouldOverwriteIncomingImage() {
        setScanImagePair(
          imageHistory.pendingImages[0],
          columnID: 0)
      } else {
        setScanImagePair(
          imageHistory.pixelTracker,
          columnID: 0,
          overridingStatistics: state.lastImageStatistics)
      }
    } else {
      let image = imageHistory.pendingImages[0]
      guard let image else {
        return
      }
      
      func getLaneID() -> Int {
        switch Self.auxiliaryImageType {
        case .incoming:
          fatalError("This should never happen.")
        case .splitCurrent:
          return 0
        case .splitHeight:
          return 1
        }
      }
      
      let (even, odd) = image.split()
      let laneID = getLaneID()
      setScanImage(
        even,
        pixelLaneID: laneID,
        rowID: 0,
        columnID: 0)
      setScanImage(
        odd,
        pixelLaneID: laneID,
        rowID: 1,
        columnID: 0)
    }
  }
  
  func setScanImagePair(
    _ pixelTracker: PixelTracker?,
    columnID: Int,
    overridingStatistics: PixelTracker.Statistics? = nil
  ) {
    setScanImage(
      pixelTracker,
      pixelLaneID: 0,
      rowID: 0,
      columnID: columnID,
      overridingStatistics: overridingStatistics)
    setScanImage(
      pixelTracker,
      pixelLaneID: 1,
      rowID: 1,
      columnID: columnID,
      overridingStatistics: overridingStatistics)
  }
  
  func setScanImage(
    _ pixelTracker: PixelTracker?,
    pixelLaneID: Int,
    rowID: Int,
    columnID: Int,
    overridingStatistics: PixelTracker.Statistics? = nil
  ) {
    guard let pixelTracker, pixelTracker.receivedRowCount > 0 else {
      return
    }
    
    let data = pixelTracker.dataBuffer.map { $0[pixelLaneID] }
    let dataNumpy = castToNumpy(data)
    
    let imagePlot = scanImagePlots[rowID][columnID]
    imagePlot.imageItem.setImage(dataNumpy, autoLevels: false)
    
    let transform = settings.realSpaceTransform(channelID: columnID)
    imagePlot.imageItem.setTransform(transform)
    
    func createLevels() -> SIMD2<Float> {
      let statistics = overridingStatistics ?? pixelTracker.statistics!
      
      if pixelLaneID == 0 {
        let average = statistics.average[0]
        var stddev = statistics.stddev[0]
        stddev = max(stddev, 0.1)
        
        return SIMD2<Float>(
          average - stddev * 3,
          average + stddev * 3)
      } else {
        let minimum = statistics.minimum[1]
        let maximum = statistics.maximum[1]
        let dz = maximum - minimum
        
        if dz < 0.01 {
          let center = (minimum + maximum) / 2
          return SIMD2(center - 0.005, center + 0.005)
        } else {
          return SIMD2(minimum, maximum)
        }
      }
    }
    
    let levels = createLevels()
    imagePlot.colorBar.setLevels(
      low: levels[0],
      high: levels[1])
  }
  
  func setFourierImage(
    _ pixelTracker: PixelTracker?,
    columnID: Int
  ) {
    guard let pixelTracker else {
      return
    }
    
    let realSpaceData = pixelTracker.dataBuffer.map {
      $0[0] / settings.setpointCurrent
    }
    let fourierSpaceData = Self.fourierTransform(castToNumpy(realSpaceData))
    
    let imagePlot = fourierImagePlots[columnID]
    imagePlot.imageItem.setImage(fourierSpaceData, autoLevels: false)
    
    let transform = settings.fourierSpaceTransform()
    imagePlot.imageItem.setTransform(transform)
    
    let maximum = Float(np.nanmax(fourierSpaceData))!
    imagePlot.colorBar.setLevels(
      low: maximum - 40,
      high: maximum)
  }
}
