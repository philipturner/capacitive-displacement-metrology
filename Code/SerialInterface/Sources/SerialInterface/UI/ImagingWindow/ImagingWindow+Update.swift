extension ImagingWindow {
  func update(output: History.Output) {
    guard output.longTimeData.count > 0 else {
      return
    }
    
    updateHistoryRanges(output: output)
    updateHistoryPlots(output: output)
    
    let historyLines = pendingHistoryLines
    let pixelSegments = state.split(lines: pendingPixelLines)
    pendingHistoryLines = []
    pendingPixelLines = []
    
    updateTrajectoryPlot(
      historyLines: historyLines,
      pixelSegments: pixelSegments)
    
    updateScanImages()
    updateFourierImage()
    for i in state.pendingImages.indices {
      state.pendingImages[i] = nil
    }
    
    plotDataValid = true
  }
  
  func updateHistoryRanges(output: History.Output) {
    func updateLongTime() {
      let maximum = output.longTimeData.last!.time
      
      var longTimeDesc = UI.TimeAxisDescriptor()
      longTimeDesc.minimum = maximum - TimeAxis.longLength
      longTimeDesc.maximum = maximum
      longTimeDesc.majorTick = TimeAxis.longMajorTick
      
      let plot = historyPlots[0].plot
      UI.updateTimeAxis(
        plots: [plot],
        descriptor: longTimeDesc)
    }
    
    func updateYAxis() {
      let axisBounds = UI.axisBounds(data: output.longTimeData)
      
      let rangeCurrent = axisBounds[0]
      let rangeX = axisBounds[1]
      let rangeY = axisBounds[2]
      let rangeZ = axisBounds[3]
      
      let plotCurrent = historyPlots[0].plot
      let plotZ = historyPlots[1].plot
      let plotXY = historyPlots[2].plot
      
      plotCurrent.setYRange(
        rangeCurrent[0],
        rangeCurrent[1],
        padding: 0)
      plotZ.setYRange(
        rangeZ[0],
        rangeZ[1],
        padding: 0)
      plotXY.setXRange(
        rangeX[0],
        rangeX[1],
        padding: 0)
      plotXY.setYRange(
        rangeY[0],
        rangeY[1],
        padding: 0)
    }
    
    updateLongTime()
    updateYAxis()
  }
  
  func updateHistoryPlots(output: History.Output) {
    for plotID in 0..<2 {
      func getLaneID() -> Int {
        if plotID == 0 {
          return 0
        } else {
          return 3
        }
      }
      let laneID = getLaneID()
      
      var x: [Double] = []
      var minimumPoints: [Float] = []
      var averagePoints: [Float] = []
      var maximumPoints: [Float] = []
      
      for sample in output.longTimeData {
        x.append(sample.time)
        minimumPoints.append(sample.minimum[laneID])
        averagePoints.append(sample.average[laneID])
        maximumPoints.append(sample.maximum[laneID])
      }
      
      let xArray = np.array(x)
      let curves = historyPlots[plotID].curves
      curves[0].setData(xArray, np.array(minimumPoints))
      curves[1].setData(xArray, np.array(averagePoints))
      curves[2].setData(xArray, np.array(maximumPoints))
    }
  }
  
  func updateTrajectoryPlot(
    historyLines: [LineParser.Line],
    pixelSegments: [[LineParser.Line]]
  ) {
    func updateHistoryCurve() {
      var x: [Float] = []
      var y: [Float] = []
      
      for line in historyLines {
        x.append(line.values[1])
        y.append(line.values[2])
      }
      
      let curve = historyPlots[2].curves[0]
      curve.setData(np.array(x), np.array(y))
    }
    
    func updatePixelCurves() {
      if pixelSegments.count > Self.maxImagesPerFrame {
        fatalError("Exceeded allowed number of images per frame.")
      }
      
      for segmentID in 0..<Self.maxImagesPerFrame {
        var x: [Float] = []
        var y: [Float] = []
        if segmentID < pixelSegments.count {
          let segment = pixelSegments[segmentID]
          for line in segment {
            x.append(line.values[1])
            y.append(line.values[2])
          }
        }
        
        let curve = historyPlots[2].curves[1 + segmentID]
        curve.setData(np.array(x), np.array(y))
      }
    }
    
    updateHistoryCurve()
    updatePixelCurves()
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
  }
}
