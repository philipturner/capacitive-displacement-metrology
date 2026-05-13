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

do {
  let rowHeight: Int = 200
  let columnWidth: Int = 500
  win.resize(80 + 2 * columnWidth + 80, rowHeight * rowCount)
  win.ci.layout.setColumnMaximumWidth(0, columnWidth + 80)
  win.ci.layout.setColumnMaximumWidth(1, columnWidth)
  
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

/*
let HelloException = PythonClass(
            "HelloException",
            superclasses: [Python.Exception],
            members: [
                "str_prefix": "HelloException-prefix ",

                "__init__": PythonInstanceMethod { args in
                    let `self` = args[0]
                    let message = "hello \(args[1])"
                    helloOutput = String(message)

                    // Conventional `super` syntax does not work; use this instead.
                    Python.Exception.__init__(`self`, message)
                    return Python.None
                },

                // Example of function using the `self` convention instead of `args`.
                "__str__": PythonInstanceMethod { (`self`: PythonObject) in
                    return `self`.str_prefix + Python.repr(`self`)
                }
            ]
        ).pythonObject
 */

/*
 import pyqtgraph as pg
 from pyqtgraph.Qt import QtCore, QtWidgets

 class CustomAxis(pg.AxisItem):
     def resizeEvent(self, ev=None):
         # Allow default behavior to run first
         super().resizeEvent(ev)
         
         # Define exact manual position (x, y)
         # Position is relative to the AxisItem's coordinate system
         new_pos = QtCore.QPointF(50, 10)
         self.label.setPos(new_pos)

 # Usage
 app = QtWidgets.QApplication([])
 win = pg.PlotWidget(axisItems={'bottom': CustomAxis(orientation='bottom')})
 win.setLabel('bottom', 'My Custom Position Label')
 win.show()
 app.exec_()
 */

func labelClass(position: SIMD2<Float>, className: String) -> PythonObject {
  let pythonClass = PythonClass(
    className,
    superclasses: [pg.AxisItem],
    members: [
      "resizeEvent": PythonInstanceMethod { args in
        let `self` = args[0]
        let ev = args[1]
        
        // Conventional `super` syntax does not work; use this instead.
        //pg.AxisItem.resizeEvent(`self`, ev)
        
        let label = `self`.label
        label.setPos(-20, `self`.size().height() / 2)
        
        return Python.None
      }
    ]
  ).pythonObject
  return pythonClass
}

var plots: [[PythonObject]] = []
var curves: [[PythonObject]] = []

for row in 0..<rowCount {
  var plotRow: [PythonObject] = []
  var curveRow: [PythonObject] = []

  for col in 0..<2 {
    /*
     # 1. Create your custom AxisItem (e.g., for Date/Time or Categories)
     # Here we use DateAxisItem as an example
     date_axis = pg.DateAxisItem(orientation='bottom')

     # 2. Add the plot, passing axisItems={ 'position': ItemInstance }
     plot = win.addPlot(axisItems={'bottom': date_axis})

     */
    func createAxisItems() -> [String: PythonObject] {
      if row == 0, col == 0 {
        let position = SIMD2<Float>(100, 20)
        let className = "CustomAxis00"
        let pythonClass = labelClass(position: position, className: className)
        let axis = pythonClass(orientation: "left")
        return ["left:": axis]
      } else if row == 1, col == 0 {
        let position = SIMD2<Float>(50, 10)
        let className = "CustomAxis10"
        let pythonClass = labelClass(position: position, className: className)
        let axis = pythonClass(orientation: "left")
        return ["left:": axis]
      } else {
        return [:]
      }
    }
    let axisItems = createAxisItems()
    
    let plot = win.addPlot(row: row, col: col, axisItems: axisItems)
    let xAxis = plot.getAxis("bottom")
    let yAxis = plot.getAxis("left")
    
    plot.showGrid(x: true, y: true)
    if row != rowCount - 1 {
      xAxis.setStyle(showValues: false)
    }
    if col != 0 {
      yAxis.setStyle(showValues: false)
    }
    if col == 0 {
      yAxis.setWidth(80)
    }
    plot.disableAutoRange()
    
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

/*
plots[0][0].setLabel(
  "left",
  "<span style=\"font-size: 18px\">current (pA)</span>")
plots[1][0].setLabel(
  "left",
  "<span style=\"font-size: 18px\">bias voltage (V)</span>")
*/
 
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
