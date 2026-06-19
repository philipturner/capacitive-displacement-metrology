import PythonKit

extension HistoryWindow {
  func update(history: History) {
    let longTimeData = history.averages(time: TimeAxis.longLength)
    if longTimeData.count > 0 {
      var timeAxisDesc = UI.TimeAxisDescriptor()
      timeAxisDesc.duration = TimeAxis.longLength
      timeAxisDesc.endTime = longTimeData.last!.time
      timeAxisDesc.majorTick = TimeAxis.longMajorTick
      updateTimeAxis(columnID: 1, descriptor: timeAxisDesc)
      
      updateYAxis(data: longTimeData)
      
      updateLongPlots(data: longTimeData)
    }
    guard longPlotsInitialized else {
      return
    }
    
    let shortTimeData = history.samples(time: TimeAxis.shortLength)
    let trace = history.triggerEventTrace(
      bipolarHistoryTime: TimeAxis.shortLength / 2)
    
    if let trace {
      var timeAxisDesc = UI.TimeAxisDescriptor()
      timeAxisDesc.duration = trace.timeInterval[1] - trace.timeInterval[0]
      timeAxisDesc.endTime = trace.timeInterval[1]
      timeAxisDesc.majorTick = TimeAxis.shortMajorTick
      
      if case .timeInterval(_, let offset) = trace.trigger.type {
        timeAxisDesc.offset = offset
      } else {
        let offset = (trace.timeInterval[0] + trace.timeInterval[1]) / 2
        timeAxisDesc.offset = offset
      }
      updateTimeAxis(columnID: 0, descriptor: timeAxisDesc)
      
      updateShortPlots(data: trace.data)
    } else if shortTimeData.count > 0 {
      var timeAxisDesc = UI.TimeAxisDescriptor()
      timeAxisDesc.duration = TimeAxis.shortLength
      timeAxisDesc.endTime = shortTimeData.last!.time
      timeAxisDesc.majorTick = TimeAxis.shortMajorTick
      updateTimeAxis(columnID: 0, descriptor: timeAxisDesc)
      
      updateShortPlots(data: shortTimeData)
    }
  }
  
  func updateTimeAxis(columnID: Int, descriptor: UI.TimeAxisDescriptor) {
    var extractedPlots: [PythonObject] = []
    for rowID in 0..<Self.rowCount {
      let plot = self.plots[rowID][columnID]
      extractedPlots.append(plot)
    }
    
    UI.updateTimeAxis(
      plots: extractedPlots,
      descriptor: descriptor)
  }
  
  func updateYAxis(data: [History.TimedAverage]) {
    let axisBounds = UI.axisBounds(data: data)
    
    for rowID in 0..<Self.rowCount {
      let range = axisBounds[rowID]
      let plotLeft = plots[rowID][0]
      plotLeft.setYRange(range[0], range[1], padding: 0)
    }
  }
  
  func updateLongPlots(data: [History.TimedAverage]) {
    for rowID in 0..<Self.rowCount {
      var x: [Double] = []
      var minimumPoints: [Float] = []
      var averagePoints: [Float] = []
      var maximumPoints: [Float] = []
      
      for sample in data {
        x.append(sample.time)
        minimumPoints.append(sample.minimum[rowID])
        averagePoints.append(sample.average[rowID])
        maximumPoints.append(sample.maximum[rowID])
      }
      
      let xArray = np.array(x)
      let curveSet = curveSets[rowID][1]
      curveSet[0].setData(xArray, np.array(minimumPoints))
      curveSet[1].setData(xArray, np.array(averagePoints))
      curveSet[2].setData(xArray, np.array(maximumPoints))
    }
    
    longPlotsInitialized = true
  }
  
  func updateShortPlots(data: [History.TimedSample]) {
    for rowID in 0..<Self.rowCount {
      var x: [Double] = []
      var y: [Float] = []
      for sample in data {
        x.append(sample.time)
        y.append(sample.values[rowID])
      }
      
      let curveSet = curveSets[rowID][0]
      curveSet.setData(np.array(x), np.array(y))
    }
    
    shortPlotsInitialized = true
  }
}
