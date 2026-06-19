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
      fourierImagePlot.plot.hide()
      labels[3].hide()
    } else {
      fourierImagePlot.plot.show()
      labels[3].show()
    }
  }
  
  func resetImages() {
    resetScanImage(columnID: 0)
    resetScanImage(columnID: 1)
    resetFourierImage()
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
  
  func resetFourierImage() {
    let emptyData = [Float](repeating: 0, count: settings.pixelsPerImage)
    let dataNumpy = castToNumpy(emptyData)
    let imagePlot = fourierImagePlot
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
      setScanImage(imageHistory.pendingImages[0], columnID: 0)
      setScanImage(imageHistory.pendingImages[1], columnID: 1)
    } else {
      if let pendingImage = imageHistory.pendingImages[0] {
        state.lastImageStatistics = pendingImage.statistics
      }
      
      func shouldFillFirst() -> Bool {
        let newPixelTracker = imageHistory.pixelTracker
        let oldImage = imageHistory.pendingImages[0]
        guard oldImage != nil else {
          return false
        }
        
        if newPixelTracker.statistics == nil {
          return true
        } else {
          return false
        }
      }
      
      if shouldFillFirst() {
        setScanImage(imageHistory.pendingImages[0], columnID: 0)
      } else {
        setScanImage(
          imageHistory.pixelTracker,
          columnID: 0,
          overridingStatistics: state.lastImageStatistics)
      }
      setScanImage(imageHistory.pendingImages[0], columnID: 1)
      setFourierImage(imageHistory.pendingImages[0])
    }
  }
  
  func setScanImage(
    _ pixelTracker: PixelTracker?,
    columnID: Int,
    overridingStatistics: PixelTracker.Statistics? = nil
  ) {
    guard let pixelTracker else {
      return
    }
    guard let statistics = pixelTracker.statistics else {
      return
    }
    
    for rowID in 0..<2 {
      let data = pixelTracker.dataBuffer.map {
        let value = $0[rowID]
        guard Self.logScaleCurrentPlotting, rowID == 0 else {
          return value
        }
        
        var output = max(0.001, value)
        output = log10(output)
        return output
      }
      let dataNumpy = castToNumpy(data)
      
      let imagePlot = scanImagePlots[rowID][columnID]
      imagePlot.imageItem.setImage(dataNumpy, autoLevels: false)
      
      let transform = settings.realSpaceTransform(channelID: columnID)
      imagePlot.imageItem.setTransform(transform)
      
      // TODO: Final piece of functionality needed: Option to split the fully
      // received current image into even and odd rows, overwriting the space
      // for the incoming image. This is disallowed in dual video mode.
      //
      // Track the Fourier transform of left and right current images
      // separately in this mode, and hide the label for the Fourier plot.
      //
      // Add gridlines for aligning offsets of individual atoms.
      func createLevels() -> SIMD2<Float> {
        if rowID == 0 {
          if Self.logScaleCurrentPlotting {
            let minimum = settings.setpointCurrent * 0.4
            let maximum = settings.setpointCurrent * 1.5
            return SIMD2<Float>(
              log10(minimum),
              log10(maximum))
          } else {
            let usedStatistics = overridingStatistics ?? statistics
            let average = usedStatistics.average[rowID]
            var stddev = usedStatistics.stddev[rowID]
            stddev = max(stddev, 0.1)
            return SIMD2<Float>(
              average - stddev * 3,
              average + stddev * 3)
          }
        } else {
          let minimum = statistics.minimum[rowID]
          let maximum = statistics.maximum[rowID]
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
      
      Self.axisItemSetpointCurrent = settings.setpointCurrent
      imagePlot.colorBar.setLevels(
        low: levels[0],
        high: levels[1])
    }
  }
  
  func setFourierImage(_ pixelTracker: PixelTracker?) {
    guard let pixelTracker else {
      return
    }
    
    let realSpaceData = pixelTracker.dataBuffer.map {
      $0[0] / settings.setpointCurrent
    }
    let fourierSpaceData = Self.fourierTransform(castToNumpy(realSpaceData))
    fourierImagePlot.imageItem.setImage(fourierSpaceData, autoLevels: false)
    
    let transform = settings.fourierSpaceTransform()
    fourierImagePlot.imageItem.setTransform(transform)
    
    let maximum = Float(np.nanmax(fourierSpaceData))!
    fourierImagePlot.colorBar.setLevels(
      low: maximum - 40,
      high: maximum)
  }
}
