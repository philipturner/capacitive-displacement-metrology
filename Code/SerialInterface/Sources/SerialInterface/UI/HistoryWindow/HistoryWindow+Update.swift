import PythonKit

extension HistoryWindow {
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
  }
}

extension HistoryWindow {
  func update(output: History.Output) {
    guard output.shortTimeData.count > 0,
          output.longTimeData.count > 0 else {
      return
    }
    
    func updateShortTimeForHistory() {
      let maximum = output.shortTimeData.last!.time
      
      var shortTimeDesc = UI.TimeAxisDescriptor()
      shortTimeDesc.minimum = maximum - TimeAxis.shortLength
      shortTimeDesc.maximum = maximum
      shortTimeDesc.majorTick = TimeAxis.shortMajorTick
      updateTimeAxis(columnID: 0, descriptor: shortTimeDesc)
    }
    
    func updateLongTime() {
      let maximum = output.longTimeData.last!.time
      
      var longTimeDesc = UI.TimeAxisDescriptor()
      longTimeDesc.minimum = maximum - TimeAxis.longLength
      longTimeDesc.maximum = maximum
      longTimeDesc.majorTick = TimeAxis.longMajorTick
      updateTimeAxis(columnID: 1, descriptor: longTimeDesc)
    }
    
    func updateShortTimeForTrigger(
      trace: History.TriggerEventTrace
    ) {
      var shortTimeDesc = UI.TimeAxisDescriptor()
      shortTimeDesc.minimum = trace.timeInterval[0]
      shortTimeDesc.maximum = trace.timeInterval[1]
      shortTimeDesc.majorTick = TimeAxis.shortMajorTick
      
      if case .timeInterval(_, let offset) = trace.trigger.type {
        shortTimeDesc.offset = offset
      } else {
        let offset = (trace.timeInterval[0] + trace.timeInterval[1]) / 2
        shortTimeDesc.offset = offset
      }
      
      updateTimeAxis(columnID: 0, descriptor: shortTimeDesc)
    }
    
    updateLongTime()
    updateLongPlots(data: output.longTimeData)
    updateYAxis(data: output.longTimeData)
    
    if let trace = output.trace {
      updateShortTimeForTrigger(trace: trace)
      updateShortPlots(data: trace.data)
    } else {
      updateShortTimeForHistory()
      updateShortPlots(data: output.shortTimeData)
    }
    
    plotDataValid = true
  }
}
