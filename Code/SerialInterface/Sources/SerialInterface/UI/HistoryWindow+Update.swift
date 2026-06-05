import PythonKit

extension HistoryWindow {
  struct TimeAxisDescriptor {
    /// Required. The start of the time interval.
    var minimum: Double?
    
    /// Required. The end of the time interval.
    var maximum: Double?
    
    /// Required. Spacing for major ticks.
    var majorTick: Double?
    
    /// Optional. Origin for ticks.
    var offset: Double?
  }
  
  func updateTime(columnID: Int, descriptor: TimeAxisDescriptor) {
    guard let minimum = descriptor.minimum,
          let maximum = descriptor.maximum,
          let majorTick = descriptor.majorTick else {
      fatalError("Descriptor was incomplete.")
    }
    
    for rowID in 0..<Self.rowCount {
      let plot = plots[rowID][columnID]
      if rowID == 0 {
        plot.setXRange(minimum, maximum, padding: 0)
      }
      
      let xAxis = plot.getAxis("bottom")
      let minorTick = majorTick / 5
      if let offset = descriptor.offset {
        let levels: [PythonObject] = [
          PythonObject(tupleOf: majorTick, offset),
          PythonObject(tupleOf: minorTick, offset),
        ]
        xAxis.setTickSpacing(levels: levels)
      } else {
        xAxis.setTickSpacing(majorTick, minorTick)
      }
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
  
  func updateYRange(data: [History.TimedAverage]) {
    guard data.count > 0 else {
      return
    }
    
    for rowID in 0..<Self.rowCount {
      var minimum: Float = .greatestFiniteMagnitude
      var maximum: Float = -.greatestFiniteMagnitude
      for sampleID in data.indices {
        let sample = data[sampleID]
        
        let sampleMin = sample.minimum[rowID]
        let sampleMax = sample.maximum[rowID]
        if sampleMin < minimum {
          minimum = sampleMin
        }
        if sampleMax > maximum {
          maximum = sampleMax
        }
      }
      
      func getRange() -> SIMD2<Float> {
        let center = (minimum + maximum) / 2
        let halfRange = maximum - center
        
        if halfRange == 0 {
          if center > 0 {
            return SIMD2(center * 0.99, center * 1.01)
          } else if center < 0 {
            return SIMD2(center * 1.01, center * 0.99)
          } else {
            return SIMD2(-1, 1)
          }
        } else {
          let rangeMin = center - halfRange * 1.1
          let rangeMax = center + halfRange * 1.1
          return SIMD2(rangeMin, rangeMax)
        }
      }
      let range = getRange()
      
      let plotLeft = plots[rowID][0]
      plotLeft.setYRange(range[0], range[1], padding: 0)
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
      
      var shortTimeDesc = HistoryWindow.TimeAxisDescriptor()
      shortTimeDesc.minimum = maximum - TimeAxis.shortLength
      shortTimeDesc.maximum = maximum
      shortTimeDesc.majorTick = TimeAxis.shortMajorTick
      updateTime(columnID: 0, descriptor: shortTimeDesc)
    }
    func updateLongTime() {
      let maximum = output.longTimeData.last!.time
      
      var longTimeDesc = HistoryWindow.TimeAxisDescriptor()
      longTimeDesc.minimum = maximum - TimeAxis.longLength
      longTimeDesc.maximum = maximum
      longTimeDesc.majorTick = TimeAxis.longMajorTick
      updateTime(columnID: 1, descriptor: longTimeDesc)
    }
    func updateShortTimeForTrigger(
      trace: History.TriggerEventTrace
    ) {
      var shortTimeDesc = HistoryWindow.TimeAxisDescriptor()
      shortTimeDesc.minimum = trace.timeInterval[0]
      shortTimeDesc.maximum = trace.timeInterval[1]
      shortTimeDesc.majorTick = TimeAxis.shortMajorTick
      
      if case .timeInterval(_, let offset) = trace.trigger.type {
        shortTimeDesc.offset = offset
      } else {
        let offset = (trace.timeInterval[0] + trace.timeInterval[1]) / 2
        shortTimeDesc.offset = offset
      }
      
      updateTime(columnID: 0, descriptor: shortTimeDesc)
    }
    
    updateLongTime()
    updateLongPlots(data: output.longTimeData)
    updateYRange(data: output.longTimeData)
    
    if let trace = output.trace {
      updateShortTimeForTrigger(trace: trace)
      updateShortPlots(data: trace.data)
    } else {
      updateShortTimeForHistory()
      updateShortPlots(data: output.shortTimeData)
    }
  }
}
