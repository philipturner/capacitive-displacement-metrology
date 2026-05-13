extension UI {
  struct TimeAxisDescriptor {
    /// The amount of elapsed time.
    var length: Double = .zero
    
    /// Spacing for major ticks.
    var majorTick: Double = .zero
    
    /// Optional. Custom spacing for minor ticks.
    var minorTick: Double?
    
    /// Required.
    var maximum: Double?
  }
  
  func updateTime(columnID: Int, descriptor: TimeAxisDescriptor) {
    guard let maxTime = descriptor.maximum else {
      fatalError("Descriptor was incomplete.")
    }
    
    for rowID in 0..<UI.rowCount {
      let plot = plots[rowID][columnID]
      if rowID == 0 {
        let minTime = maxTime - descriptor.length
        plot.setXRange(minTime, maxTime, padding: 0)
      }
      
      let majorTick = descriptor.majorTick
      let minorTick = descriptor.minorTick ?? majorTick / 5
      let xAxis = plot.getAxis("bottom")
      xAxis.setTickSpacing(majorTick, minorTick)
    }
  }
  
  func updateShortPlots(data: [History.TimedSample]) {
    for rowID in 0..<UI.rowCount {
      var x: [Double] = []
      var y: [Float] = []
      for sample in data {
        x.append(sample.time)
        y.append(sample.values[rowID])
      }
      
      curves[rowID][0].setData(
        np.array(x),
        np.array(y))
    }
  }
  
  func updateLongPlots(data: [History.TimedAverage]) {
    for rowID in 0..<UI.rowCount {
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
      let curveSet = curves[rowID][1]
      curveSet[0].setData(xArray, np.array(minimumPoints))
      curveSet[1].setData(xArray, np.array(averagePoints))
      curveSet[2].setData(xArray, np.array(maximumPoints))
    }
  }
  
  func updateYRange(data: [History.TimedAverage]) {
    for rowID in 0..<UI.rowCount {
      var minimum: Float = .greatestFiniteMagnitude
      var maximum: Float = -.greatestFiniteMagnitude
      for sample in data {
        let sampleMin = sample.minimum[rowID]
        let sampleMax = sample.maximum[rowID]
        if sampleMin < minimum {
          minimum = sampleMin
        }
        if sampleMax > maximum {
          maximum = sampleMax
        }
      }
      
      let center = (minimum + maximum) / 2
      let halfRange = maximum - center
      let rangeMin = center - halfRange * 1.1
      let rangeMax = center + halfRange * 1.1
      
      let plotLeft = plots[rowID][0]
      plotLeft.setYRange(rangeMin, rangeMax, padding: 0)
    }
  }
}
