import Foundation
import PythonKit

extension ImagingWindow {
  func update(output: History.Output) {
    guard output.longTimeData.count > 0 else {
      return
    }
    
    updateHistoryRanges(output: output)
    updateHistoryPlots(output: output)
    
    if state.trajectorySynchronization == nil {
      if pendingHistoryLines.count > 0 {
        let timestamp = Date().timeIntervalSince1970
        let lineID = pendingHistoryLines.count
        state.trajectorySynchronization = (timestamp, lineID)
      }
    }
    
    let historyLines = pendingHistoryLines
    if let trajectoryLagTime = trajectoryLagTime {
      if let synchronization = state.trajectorySynchronization {
        let currentTime = Date().timeIntervalSince1970
        let pastTime = currentTime - 0.1
        let deltaTime = pastTime - synchronization.timestamp
        
        let timePerLine = 1e-6 * Double(History.logPeriodMicros)
        let deltaLines = Int(deltaTime / timePerLine)
        var maxLineID = synchronization.lineID + deltaLines
        maxLineID -= state.deletedHistoryLineCount
        
        if maxLineID > 0 {
          let deletedLineCount = min(maxLineID, pendingHistoryLines.count)
          pendingHistoryLines = Array(pendingHistoryLines[deletedLineCount...])
          state.deletedHistoryLineCount += deletedLineCount
        }
      }
    } else {
      pendingHistoryLines = []
    }
    
    let pixelSegments = state.split(lines: pendingPixelLines)
    pendingPixelLines = []
    
    updateTrajectoryPlot(
      historyLines: historyLines,
      pixelSegments: pixelSegments)
    
    state.update(segments: pixelSegments)
    updateScanImages()
    updateFourierImage()
    
    if state.settings.mode == .image {
      if state.pendingImages[0] != nil {
        state.freezeTrajectory = true
      }
    }
    
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
      
      let plots = [
        historyPlots[0].plot,
        historyPlots[1].plot,
      ]
      UI.updateTimeAxis(
        plots: plots,
        descriptor: longTimeDesc)
    }
    
    func updateYAxis() {
      let axisBounds = UI.axisBounds(data: output.longTimeData)
      
      let rangeCurrent = axisBounds[0] * 1e12
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
      
      if !state.freezeTrajectory {
        let centerX = rangeX.sum() / 2
        let centerY = rangeY.sum() / 2
        let spanX = rangeX[1] - rangeX[0]
        let spanY = rangeY[1] - rangeY[0]
        let maxSpan = max(spanX, spanY)
        
        let newRangeX = SIMD2(
          centerX - maxSpan / 2,
          centerX + maxSpan / 2)
        let newRangeY = SIMD2(
          centerY - maxSpan / 2,
          centerY + maxSpan / 2)
        
        plotXY.setXRange(
          newRangeX[0],
          newRangeX[1],
          padding: 0)
        plotXY.setYRange(
          newRangeY[0],
          newRangeY[1],
          padding: 0)
        
        let majorTick = maxSpan / 5
        let minorTick = majorTick / 5
        let offset: Float = 1.0
        
        let levels: [PythonObject] = [
          PythonObject(tupleOf: majorTick, offset),
          PythonObject(tupleOf: minorTick, offset),
        ]
        let xAxis = plotXY.getAxis("bottom")
        let yAxis = plotXY.getAxis("left")
        xAxis.setTickSpacing(majorTick, minorTick)
        yAxis.setTickSpacing(majorTick, minorTick)
      }
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
        
        func getMultiplier() -> Float {
          if plotID == 0 {
            return 1e12
          } else {
            return 1
          }
        }
        let multiplier = getMultiplier()
        
        minimumPoints.append(sample.minimum[laneID] * multiplier)
        averagePoints.append(sample.average[laneID] * multiplier)
        maximumPoints.append(sample.maximum[laneID] * multiplier)
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
    
    if !state.freezeTrajectory {
      updateHistoryCurve()
      updatePixelCurves()
    }
  }
}
