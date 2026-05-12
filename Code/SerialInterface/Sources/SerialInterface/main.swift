import Foundation
import PythonKit
import SwiftSerial

PythonLibrary.useLibrary(at: "/Users/philipturner/miniforge3/bin/python")
let plt = Python.import("matplotlib.pyplot")
let ticker = Python.import("matplotlib.ticker")

await Application.global.initialize()

do {
  let frameRate: Int = 1
  usleep(UInt32(1_000_000 / frameRate))
  
  let shortTimeLength: Double = 0.003
  let shortTimeTick: Double = 0.001
  let longTimeLength: Double = 10.0
  let longTimeTick: Double = 1.0
  
  let history = Application.global.history
  let shortTimeData = await history.sampleHistory(time: shortTimeLength)
  let longTimeData = await history.averageHistory(time: longTimeLength)
  guard shortTimeData.count > 0,
        longTimeData.count > 0 else {
    fatalError("No data to graph.")
  }
  
  let (fig, axes) = plt.subplots(4, 2, layout: "constrained").tuple2
  for rowID in 0..<4 {
    for columnID in 0..<2 {
      let subplotIndex = PythonObject(tupleOf: rowID, columnID)
      
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
    }
  }
  fig.set_size_inches(12, 10)
  
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
  
  print("started showing the plot")
  plt.show()
  print("finished showing the plot")
}
