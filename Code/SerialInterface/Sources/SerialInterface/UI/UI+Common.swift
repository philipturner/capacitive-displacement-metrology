import PythonKit

extension UI {
  static let thicknessFactor: Int = 1
  
  static func connectCloseShortcut(win: PythonObject) {
    let shortcut = QtWidgets.QShortcut(QtGui.QKeySequence("Ctrl+W"), win)
    
    let closeEvent = PythonFunction { args in
      Application.needsToClose = true
      return Python.None
    }.pythonObject
    
    // Makes the application close when "Ctrl + W" is typed, and the window
    // 'win' is in focus.
    shortcut.activated.connect(closeEvent)
    
    // Makes the application close after pressing the red button to close the
    // window.
    win.closeEvent = closeEvent
  }
  
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

extension UI {
  static func setThickness(axis: PythonObject) {
    let pen = axis.pen()
    pen.setWidth(Self.thicknessFactor)
    axis.setPen(pen)
  }
  
  static let VerticalLabel = createVerticalLabel()
  
  private static func createVerticalLabel() -> PythonObject {
    PythonClass(
      "VerticalLabel",
      superclasses: [QtWidgets.QLabel],
      members: [
        "__init__": PythonInstanceMethod { [QtWidgets] args in
          let `self` = args[0]
          guard args.count == 3 else {
            fatalError("Was expecting just the text as an argument.")
          }
          QtWidgets.QLabel.__init__(`self`, args[1], args[2])
          
          return Python.None
        },
        
        "paintEvent": PythonInstanceMethod { [QtGui, QtCore] args in
          let `self` = args[0]
          guard args.count == 2 else {
            fatalError("Was expecting just the event as an argument.")
          }
          
          let painter = QtGui.QPainter(`self`)
          `self`.setAttribute(QtCore.Qt.WA_TranslucentBackground)
          
          painter.translate(`self`.rect().center())
          painter.rotate(-90)
          painter.translate(-`self`.rect().center())
          painter.drawText(`self`.rect(), QtCore.Qt.AlignCenter, `self`.text())
          
          return Python.None
        },
        
        "minimumSizeHint": PythonInstanceMethod { [QtWidgets, QtCore] args in
          let `self` = args[0]
          let size = QtWidgets.QLabel.minimumSizeHint(`self`)
          return QtCore.QSize(size.height(), size.width())
        },
        
        "sizeHint": PythonInstanceMethod { [QtWidgets, QtCore] args in
          let `self` = args[0]
          let size = QtWidgets.QLabel.sizeHint(`self`)
          return QtCore.QSize(size.height(), size.width())
        }
      ]
    ).pythonObject
  }
}
