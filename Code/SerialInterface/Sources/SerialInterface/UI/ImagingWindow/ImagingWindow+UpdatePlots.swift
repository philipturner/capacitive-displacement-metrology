import Foundation
import PythonKit

extension ImagingWindow {
  func updatePlots(data: [History.TimedAverage]) {
    let axisBounds = UI.axisBounds(data: data)
    updateTimeAxis(data: data)
    updateCurrentRange(axisBounds[0])
    updateZRange(axisBounds[3])
    
    func trajectoryIsFrozen() -> Bool {
      guard settings.mode == .image else {
        return false
      }
      
      if imageHistory.receivedPixelCount >= settings.pixelsPerImage {
        return true
      } else {
        return false
      }
    }
    
    if !trajectoryIsFrozen() {
      updateTrajectoryRange(x: axisBounds[1], y: axisBounds[2])
      updateTrajectoryCurve()
      updatePixelCurves()
    }
    
    do {
      let pixelSegments = state.split(lines: pendingPixelLines)
      state.update(segments: pixelSegments)
    }
    updateScanImages()
    updateFourierImage()
    
    

  }
  
  func updateTimeAxis(data: [History.TimedAverage]) {
    let maximum = data.last!.time
    
    var longTimeDesc = UI.TimeAxisDescriptor()
    longTimeDesc.minimum = maximum - TimeAxis.longLength
    longTimeDesc.maximum = maximum
    longTimeDesc.majorTick = TimeAxis.longMajorTick
    
    let plots = [
      self.plots[0].plot,
      self.plots[1].plot,
    ]
    UI.updateTimeAxis(
      plots: plots,
      descriptor: longTimeDesc)
  }
  
  func updateCurrentRange(_ range: SIMD2<Float>) {
    let plot = plots[0].plot
    plot.setYRange(range[0], range[1], padding: 0)
  }
  
  func updateZRange(_ range: SIMD2<Float>) {
    let plot = plots[1].plot
    plot.setYRange(range[0], range[1], padding: 0)
  }
  
  func updateTrajectoryRange(
    x rangeX: SIMD2<Float>,
    y rangeY: SIMD2<Float>
  ) {
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
    
    let plotXY = plots[2].plot
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
    
    let xAxis = plotXY.getAxis("bottom")
    let yAxis = plotXY.getAxis("left")
    xAxis.setTickSpacing(majorTick, minorTick)
    yAxis.setTickSpacing(majorTick, minorTick)
  }
  
  func updateHistoryPlots(data: [History.TimedAverage]) {
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
      
      for sample in data {
        x.append(sample.time)
        
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
  
  func updateTrajectoryCurve() {
    var x: [Float] = []
    var y: [Float] = []
    for line in state.trajectory.historyLines {
      x.append(line.values[1])
      y.append(line.values[2])
    }
    
    let curve = plots[2].curves[0]
    curve.setData(np.array(x), np.array(y))
  }
  
  func updatePixelCurves() {
    let lines = state.trajectory.pixelLines
    let segments = settings.split(lines: lines)
    if segments.count > Self.maxImagesPerFrame {
      fatalError("Exceeded allowed number of images per frame.")
    }
    
    for segmentID in 0..<Self.maxImagesPerFrame {
      var x: [Float] = []
      var y: [Float] = []
      if segmentID < segments.count {
        let segment = segments[segmentID]
        for line in segment {
          x.append(line.values[1])
          y.append(line.values[2])
        }
      }
      
      let curve = plots[2].curves[1 + segmentID]
      curve.setData(np.array(x), np.array(y))
    }
  }
}
