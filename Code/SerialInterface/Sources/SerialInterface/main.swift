import Foundation
import PythonKit
import SwiftSerial

PythonLibrary.useLibrary(at: "/Users/philipturner/miniforge3/bin/python")
//let matplotlib = Python.import("matplotlib")
//Python.import("matplotlib").use("Qt5Agg")
let plt = Python.import("matplotlib.pyplot")
let ticker = Python.import("matplotlib.ticker")

await Application.global.initialize()

plt.ion()
var (fig, axes) = plt.subplots(4, 2, layout: "constrained").tuple2
fig.set_size_inches(8, 10)
//fig.canvas.manager.window.move(500, 500)

let startTime = Date().timeIntervalSince1970

while Bool(plt.fignum_exists(fig.number))! {
  let frameRate: Int = 6
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
      let subplotIndex = PythonObject(tupleOf: rowID, columnID)
      axes[subplotIndex].clear()
      
      if columnID == 0 {
        let maxTime = shortTimeData.last!.time
        let minTime = maxTime - shortTimeLength
        axes[subplotIndex].set_xlim(minTime, maxTime)
      } else {
        let maxTime = longTimeData.last!.time
        let minTime = maxTime - longTimeLength
        axes[subplotIndex].set_xlim(minTime, maxTime)
      }
      
      let timeTick = (columnID == 0) ? shortTimeTick : longTimeTick
      let majorLocator = ticker.MultipleLocator(timeTick)
      let minorLocator = ticker.MultipleLocator(timeTick / 5)
      axes[subplotIndex].xaxis.set_major_locator(majorLocator)
      axes[subplotIndex].xaxis.set_minor_locator(minorLocator)
      
      if columnID == 0 {
        let majorFormatter = ticker.FormatStrFormatter("%.3f")
        axes[subplotIndex].xaxis.set_major_formatter(majorFormatter)
      }
      
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
      
      if rowID != 3 {
        axes[subplotIndex].tick_params(labelbottom: false)
      }
      if columnID != 0 {
        axes[subplotIndex].tick_params(labelleft: false)
      }
    }
  }
  
  for rowID in 0..<4 {
    var x: [Double] = []
    var y: [Float] = []
    for sample in shortTimeData {
      x.append(sample.time)
      y.append(sample.values[rowID])
    }
    
    axes[rowID, 0].plot(x, y)
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
    
    axes[rowID, 1].plot(x, minimumPoints, color: "#1fb864")
    axes[rowID, 1].plot(x, averagePoints, color: "orange")
    axes[rowID, 1].plot(x, maximumPoints, color: "red")
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
    axes[rowID, 0].set_ylim(rangeMin, rangeMax)
    axes[rowID, 1].set_ylim(rangeMin, rangeMax)
  }
  
  let time3 = Date().timeIntervalSince1970
  
  fig.canvas.draw_idle()
  
  
  let time4 = Date().timeIntervalSince1970
  
//  fig.canvas.flush_events()
  plt.pause(0.001)
  
  let time5 = Date().timeIntervalSince1970
  
  func display(_ start: Double, _ end: Double) {
    let dt = end - start
    let formatted = String(format: "%.3f", dt)
    print("- \(formatted) s")
  }
  display(time1, time2)
  display(time2, time3)
  display(time3, time4)
  display(time4, time5)
}
