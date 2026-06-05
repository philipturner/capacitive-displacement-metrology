import PythonKit

extension UI {
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
  
  static func updateTimeAxis(
    plots: [PythonObject],
    descriptor: TimeAxisDescriptor
  ) {
    guard let minimum = descriptor.minimum,
          let maximum = descriptor.maximum,
          let majorTick = descriptor.majorTick else {
      fatalError("Descriptor was incomplete.")
    }
    plots[0].setXRange(minimum, maximum, padding: 0)
    
    for plotID in plots.indices {
      let plot = plots[plotID]
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
  
  static func axisBounds(
    data: [History.TimedAverage]
  ) -> [SIMD2<Float>] {
    guard data.count > 0 else {
      fatalError("No data elements.")
    }
    
    var minAccumulator = SIMD8<Float>(repeating: .greatestFiniteMagnitude)
    var maxAccumulator = SIMD8<Float>(repeating: -.greatestFiniteMagnitude)
    for sampleID in data.indices {
      let sample = data[sampleID]
      minAccumulator.replace(
        with: sample.minimum,
        where: sample.minimum .< minAccumulator)
      maxAccumulator.replace(
        with: sample.maximum,
        where: sample.maximum .> maxAccumulator)
    }
    
    var output: [SIMD2<Float>] = []
    for laneID in 0..<8 {
      let minimum = minAccumulator[laneID]
      let maximum = maxAccumulator[laneID]
      
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
      output.append(range)
    }
    return output
  }
}
