import Foundation
import PythonKit
import SwiftSerial

PythonLibrary.useLibrary(at: "/Users/philipturner/miniforge3/bin/python")
let pg = Python.import("pyqtgraph")
let QtWidgets = Python.import("PyQt5.QtWidgets")
let QtCore = Python.import("PyQt5.QtCore")

await Application.global.initialize()

let app = QtWidgets.QApplication([String]())
let win = pg.GraphicsLayoutWidget(show: true)
win.resize(1200, 900)
//win.setWindowTitle("Live Data")

win.ci.layout.setColumnMaximumWidth(0, 580)
win.ci.layout.setColumnMaximumWidth(1, 580)

//let layout = win.ci.layout
//layout.setColumnStretchFactor(0, 1)
//layout.setColumnStretchFactor(1, 1)

var plots: [[PythonObject]] = []
var curves: [[PythonObject]] = []

for row in 0..<4 {
  var plotRow: [PythonObject] = []
  var curveRow: [PythonObject] = []

  for col in 0..<2 {
    let plot = win.addPlot(row: row, col: col)
    let xAxis = plot.getAxis("bottom")
    let yAxis = plot.getAxis("left")
    
    plot.showGrid(x: true, y: true)
    if row != 3 {
      xAxis.setStyle(showValues: false)
    }
    if col != 0 {
      yAxis.setStyle(showValues: false)
    }
    
    // Create persistent curves
    let emptyArray = [Float]()
    if col == 0 {
      let curve = plot.plot(emptyArray, emptyArray, pen: pg.mkPen("blue"))
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

for row in 1..<4 {
  plots[row][0].setXLink(plots[0][0])
  plots[row][1].setXLink(plots[0][1])
  plots[row][1].setYLink(plots[row][0])
}


let startTime = Date().timeIntervalSince1970

// TODO: End loop when window is closed.
while true {
  let frameRate: Int = 2
  usleep(UInt32(1_000_000 / frameRate))
  
  do {
    let currentTime = Date().timeIntervalSince1970
    let elapsedTime = currentTime - startTime
    let formattedTime = String(format: "%.3f", elapsedTime)
    print()
    print("time: \(formattedTime) s")
  }
  
  let shortTimeLength: Double = 0.003
  let shortTimeTick: Double = 0.001
  let longTimeLength: Double = 10.0
  let longTimeTick: Double = 1.0
  
  let time1 = Date().timeIntervalSince1970
  
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
    return output
  }
  
  let dataStreams = createDataStreams()
  let shortTimeData = dataStreams.short
  let longTimeData = dataStreams.long
  guard shortTimeData.count > 0,
        longTimeData.count > 0 else {
    fatalError("No data to graph.")
  }
  
  let time2 = Date().timeIntervalSince1970
  
  for rowID in 0..<4 {
    for columnID in 0..<2 {
      let plot = plots[rowID][columnID]
      if columnID == 0 {
        let maxTime = shortTimeData.last!.time
        let minTime = maxTime - shortTimeLength
        plot.setXRange(minTime, maxTime, padding: 0)
      } else {
        let maxTime = longTimeData.last!.time
        let minTime = maxTime - longTimeLength
        plot.setXRange(minTime, maxTime, padding: 0)
      }
      
      let timeTick = (columnID == 0) ? shortTimeTick : longTimeTick
      let xAxis = plot.getAxis("bottom")
      xAxis.setTickSpacing(timeTick, timeTick / 5)
      
      /*
      axes[subplotIndex].grid(
        visible: true,
        which: "major",
        axis: "x",
        color: "0.7")
      axes[subplotIndex].grid(
        visible: true,
        which: "minor",
        axis: "x",
        color: "0.9")
      axes[subplotIndex].grid(
        visible: true,
        which: "major",
        axis: "y",
        color: "0.9")
       */
    }
  }
  
  for rowID in 0..<4 {
    var x: [Double] = []
    var y: [Float] = []
    for sample in shortTimeData {
      x.append(sample.time)
      y.append(sample.values[rowID])
    }
    
    curves[rowID][0].setData(x, y)
  }
  
  for rowID in 0..<4 {
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
    
    let curveSet = curves[rowID][1]
    curveSet[0].setData(x, minimumPoints)
    curveSet[1].setData(x, averagePoints)
    curveSet[2].setData(x, maximumPoints)
  }
  
  for rowID in 0..<4 {
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
    let plotRight = plots[rowID][1]
    plotLeft.setYRange(rangeMin, rangeMax, padding: 0)
    plotRight.setYRange(rangeMin, rangeMax, padding: 0)
  }
  
  let time3 = Date().timeIntervalSince1970
  
  app.processEvents()
  
  let time4 = Date().timeIntervalSince1970
  
  func display(_ start: Double, _ end: Double) {
    let dt = end - start
    let formatted = String(format: "%.3f", dt)
    print("- \(formatted) s")
  }
  display(time1, time2)
  display(time2, time3)
  display(time3, time4)
}
