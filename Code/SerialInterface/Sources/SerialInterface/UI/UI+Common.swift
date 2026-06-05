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
}
