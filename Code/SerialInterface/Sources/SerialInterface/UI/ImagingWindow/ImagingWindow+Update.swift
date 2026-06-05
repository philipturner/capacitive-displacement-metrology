extension ImagingWindow {
  func update(output: History.Output) {
    guard output.longTimeData.count > 0 else {
      return
    }
    updateHistoryRanges(output: output)
  }
  
  func updateState() {
    pendingHistoryLines = []
    pendingPixelLines = []
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
      
      
      
    }
  }
  
  func updateTrajectoryPlot() {
    // just check whether the current pixel row < the previous row, then you
    // detect the boundary between consecutive images
  }
  
  func updateScanImages() {
    
  }
  
  func updateFourierImage() {
    if settings.mode == .dualVideo {
      fourierImage.plot.hide()
      return
    } else {
      fourierImage.plot.show()
    }
    
    
  }
  
  func clearPendingLines() {
    
  }
}
