import Foundation
import PythonKit
import SwiftSerial

PythonLibrary.useLibrary(at: "/Users/philipturner/miniforge3/bin/python")
let np = Python.import("numpy")
let pg = Python.import("pyqtgraph")
let QtCore = Python.import("PyQt5.QtCore")
let QtGui = Python.import("PyQt5.QtGui")
let QtWidgets = Python.import("PyQt5.QtWidgets")

await Application.global.initialize()

pg.setConfigOptions(useOpenGL: true)
pg.setConfigOptions(antialias: true)
let app = QtWidgets.QApplication([String]())
let win = pg.GraphicsLayoutWidget(show: true)

let shortcut = QtWidgets.QShortcut(QtGui.QKeySequence("Ctrl+W"), win)
shortcut.activated.connect(win.close)

let rowCount: Int = 3
let rowHeight: Int = 180
let rowSpacing: Int = 20
let columnWidth: Int = 500
let columnSpacing: Int = 20
let xAxisHeight: Int = 40
let yAxisWidth: Int = 100

do {
  let x = yAxisWidth + 2 * columnWidth + columnSpacing + 40
  var y = rowCount * rowHeight + (rowCount - 1) * rowSpacing
  y += xAxisHeight + 10
  win.resize(x, y)
  win.ci.layout.setColumnMaximumWidth(0, columnWidth + yAxisWidth)
  win.ci.layout.setColumnMaximumWidth(1, columnWidth)
  
  for rowID in 0..<rowCount {
    win.ci.layout.setRowSpacing(rowID, rowSpacing)
  }
  win.ci.layout.setColumnSpacing(0, columnSpacing)
  win.ci.layout.setColumnSpacing(1, columnSpacing)
  
  // Set the window position on the screen.
  let screen = app.primaryScreen()
  let screenSize = screen.size()
  let screenDimensions = SIMD2<Float>(
    Float(screenSize.width())!,
    Float(screenSize.height())!)
  let windowDimensions = SIMD2<Float>(
    Float(win.width())!,
    Float(win.height())!)
  
  let screenMiddle = screenDimensions / 2
  let upperLeft = screenMiddle - windowDimensions / 2
  win.move(
    Int(upperLeft.x),
    Int(20))
}

var plots: [[PythonObject]] = []
var curves: [[PythonObject]] = []

for row in 0..<rowCount {
  var plotRow: [PythonObject] = []
  var curveRow: [PythonObject] = []

  for col in 0..<2 {
    let plot = win.addPlot(row: row, col: col)
    plot.showGrid(x: true, y: true)
    plot.disableAutoRange()
    
    let xAxis = plot.getAxis("bottom")
    if row == rowCount - 1 {
      plot.setFixedHeight(rowHeight + xAxisHeight)
      xAxis.setHeight(xAxisHeight)
    } else {
      plot.setFixedHeight(rowHeight)
      xAxis.setStyle(showValues: false)
    }
    
    let yAxis = plot.getAxis("left")
    if col == 0 {
      yAxis.setWidth(yAxisWidth)
    } else {
      yAxis.setStyle(showValues: false)
    }
    
    
    // Create persistent curves
    let emptyArray = [Float]()
    if col == 0 {
      let pen = pg.mkPen("#2e7ec9", width: 2)
      let curve = plot.plot(emptyArray, emptyArray, pen: pen)
      curveRow.append(curve)
    } else {
      let minCurve = plot.plot(emptyArray, emptyArray, pen: pg.mkPen("#1fb864"))
      let avgCurve = plot.plot(emptyArray, emptyArray, pen: pg.mkPen("orange"))
      let maxCurve = plot.plot(emptyArray, emptyArray, pen: pg.mkPen("red"))
      
      curveRow.append(PythonObject([minCurve, avgCurve, maxCurve]))
    }

    plotRow.append(plot)
  }

  plots.append(plotRow)
  curves.append(curveRow)
}

// If multiple graphs share a dimension, only set the bounds of one graph
// and have PyQtGraph make the rest follow it.
for row in 0..<rowCount {
  plots[row][1].setYLink(plots[row][0])
}
for row in 1..<rowCount {
  plots[row][0].setXLink(plots[0][0])
  plots[row][1].setXLink(plots[0][1])
}

let VerticalLabel = PythonClass(
  "VerticalLabel",
  superclasses: [QtWidgets.QLabel],
  members: [
    "__init__": PythonInstanceMethod { args in
      let `self` = args[0]
      guard args.count == 3 else {
        fatalError("Was expecting just the text as an argument.")
      }
      QtWidgets.QLabel.__init__(`self`, args[1], args[2])
      
      return Python.None
    },
    
    "paintEvent": PythonInstanceMethod { args in
      let `self` = args[0]
      guard args.count == 2 else {
        fatalError("Was expecting just the event as an argument.")
      }
      let event = args[1]
      
      let painter = QtGui.QPainter(`self`)
      `self`.setAttribute(QtCore.Qt.WA_TranslucentBackground)
      
      painter.translate(`self`.rect().center())
      painter.rotate(-90)
      painter.translate(-`self`.rect().center())
      painter.drawText(`self`.rect(), QtCore.Qt.AlignCenter, `self`.text())
      
      return Python.None
    },
    
    "minimumSizeHint": PythonInstanceMethod { args in
      let `self` = args[0]
      let size = QtWidgets.QLabel.minimumSizeHint(`self`)
      return QtCore.QSize(size.height(), size.width())
    },
    
    "sizeHint": PythonInstanceMethod { args in
      let `self` = args[0]
      let size = QtWidgets.QLabel.sizeHint(`self`)
      return QtCore.QSize(size.height(), size.width())
    }
  ]
).pythonObject

do {
  let labelTextList: [String] = [
    "current (pA)",
    "bias voltage (V)",
    "test channel (a.u.)"
  ]
  
  for labelID in labelTextList.indices {
    let text = labelTextList[labelID]
    let label = VerticalLabel(text, win)
    
    label.setStyleSheet("font-size: 20px;")
    label.setFixedSize(500, 500)
    label.raise_()
    label.show()
    
    let x: Int = -250 + yAxisWidth - 70
    var y: Int = -250
    y += rowHeight / 2
    y += labelID * (rowHeight + rowSpacing)
    label.move(x, y)
  }
  
  /*
  let label1 = VerticalLabel("F", win)
  let label2 = VerticalLabel("S", win)
  
  label1.setStyleSheet("font-size: 20px;")
  label1.setFixedSize(500, 500)  //# Ensure it has a width/height based on text
  label1.raise_()      // # Bring to the absolute front of the stack
  label1.show()        // # Force visibility if parent is already shown
  label1.move(-250 + yAxisWidth - 30, -250 + 100)   //# Position it
  
  label2.setStyleSheet("font-size: 20px;")
  label2.setFixedSize(500, 500)  //# Ensure it has a width/height based on text
  label2.raise_()      // # Bring to the absolute front of the stack
  label2.show()        // # Force visibility if parent is already shown
  label2.move(-250 + yAxisWidth - 30, -250 + 200 + 100)   //# Position it
   */
}

var windowIsClosed = false
win.closeEvent = PythonFunction { args in
  windowIsClosed = true
  return Python.None
}.pythonObject

// MARK: - Run Loop

var lastDrawShortTime: Double = -1
@MainActor
func getShouldDrawShort(latestSampleTime: Double) -> Bool {
  let dt = latestSampleTime.rounded(.down) - lastDrawShortTime
  if dt >= 1 {
    lastDrawShortTime = latestSampleTime.rounded(.down)
    return true
  } else {
    return false
  }
}

while !windowIsClosed {
  let maxFrameRate: Int = 60
  usleep(UInt32(1_000_000 / maxFrameRate))
  
  let shortTimeLength: Double = 0.003
  let shortTimeTick: Double = 0.001
  let longTimeLength: Double = 10.0
  let longTimeTick: Double = 1.0
  
  struct DataStreams {
    var short: [History.TimedSample] = []
    var long: [History.TimedAverage] = []
  }
  func createDataStreams() -> DataStreams {
    var output = DataStreams()
    Application.global.serialQueue.sync {
      let history = Application.global.history
      output.short = history.sampleHistory(time: shortTimeLength)
      output.long =  history.averageHistory(time: longTimeLength)
    }
    guard output.short.count > 0,
          output.long.count > 0 else {
      fatalError("No data to graph.")
    }
    return output
  }
  
  let dataStreams = createDataStreams()
  let shortTimeData = dataStreams.short
  let longTimeData = dataStreams.long
  
  let shouldDrawShort = getShouldDrawShort(
    latestSampleTime: shortTimeData.last!.time)
  
  for rowID in 0..<rowCount {
    for columnID in 0..<2 {
      if columnID == 0 {
        if !shouldDrawShort {
          continue
        }
      }
      
      let plot = plots[rowID][columnID]
      if rowID == 0 {
        if columnID == 0 {
          let maxTime = shortTimeData.last!.time
          let minTime = maxTime - shortTimeLength
          plot.setXRange(minTime, maxTime, padding: 0)
        } else {
          let maxTime = longTimeData.last!.time
          let minTime = maxTime - longTimeLength
          plot.setXRange(minTime, maxTime, padding: 0)
        }
      }
      
      let timeTick = (columnID == 0) ? shortTimeTick : longTimeTick
      let xAxis = plot.getAxis("bottom")
      xAxis.setTickSpacing(timeTick, timeTick / 5)
    }
  }
  
  if shouldDrawShort {
    for rowID in 0..<rowCount {
      var x: [Double] = []
      var y: [Float] = []
      for sample in shortTimeData {
        x.append(sample.time)
        y.append(sample.values[rowID])
      }
      
      curves[rowID][0].setData(
        np.array(x),
        np.array(y))
    }
  }
  
  for rowID in 0..<rowCount {
    var x: [Double] = []
    var minimumPoints: [Float] = []
    var averagePoints: [Float] = []
    var maximumPoints: [Float] = []
    
    for sample in longTimeData {
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
  
  if shouldDrawShort {
    for rowID in 0..<rowCount {
      var minimum: Float = .greatestFiniteMagnitude
      var maximum: Float = -.greatestFiniteMagnitude
      for sample in longTimeData {
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
  
  app.processEvents()
}
