extension ImagingWindow {
  func update(output: History.Output) {
    guard output.longTimeData.count > 0 else {
      return
    }
  }
  
  func updateHistoryRanges(output: History.Output) {
    func updateLongTime() {
      let maximum = output.longTimeData.last!.time
      
      var longTimeDesc = UI.TimeAxisDescriptor()
      longTimeDesc.minimum = maximum - TimeAxis.longLength
      longTimeDesc.maximum = maximum
      longTimeDesc.majorTick = TimeAxis.longMajorTick
      updateTimeAxis(columnID: 1, descriptor: longTimeDesc)
    }
    
    let axisBounds = UI.axisBounds(data: output.longTimeData)
  }
  
  func updateHistoryPlots(output: History.Output) {
    
  }
  
  func updateTrajectoryPlot() {
    
  }
  
  func updateScanImages() {
    
  }
  
  func updateFourierImage() {
    
  }
  
  func clearPendingLines() {
    pendingPixelLines = []
  }
}
