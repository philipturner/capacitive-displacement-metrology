import Foundation
import PythonKit
import SwiftSerial

PythonLibrary.useLibrary(at: "/Users/philipturner/miniforge3/bin/python")
let plt = Python.import("matplotlib.pyplot")
let ticker = Python.import("matplotlib.ticker")

await Application.global.initialize()

let startTime = Date().timeIntervalSince1970

while true {
  let frameRate: Int = 30
  usleep(UInt32(1_000_000 / frameRate))
  
  let currentTime = Date().timeIntervalSince1970
  
  let fetchStart = Date().timeIntervalSince1970
  
  let history = Application.global.history
  let shortTimeData = await history.sampleHistory(time: 0.005)
  let longTimeData = await history.averageHistory(time: 10.0)
  guard shortTimeData.count > 6,
        longTimeData.count > 6 else {
    fatalError("Cannot process this data.")
  }
  
  let elapsedTime = currentTime - startTime
  let elapsedTimeFormatted = String(format: "%.3f", elapsedTime)
  
//  print()
//  print("t = \(elapsedTimeFormatted) s")
//  print("shortTimeData:")
//  
//  let shortCount = shortTimeData.count
//  print("- \(shortTimeData.count) points")
//  print("- start + 0: \(shortTimeData[0])")
//  print("- start + 1: \(shortTimeData[1])")
//  print("- start + 2: \(shortTimeData[2])")
//  print("- end - 3:   \(shortTimeData[shortCount - 3])")
//  print("- end - 2:   \(shortTimeData[shortCount - 2])")
//  print("- end - 1:   \(shortTimeData[shortCount - 1])")
//  
//  let longCount = longTimeData.count
//  print("longTimeData:")
//  print("- \(longTimeData.count) points")
//  print("- start + 0: \(longTimeData[0])")
//  print("- start + 1: \(longTimeData[1])")
//  print("- start + 2: \(longTimeData[2])")
//  print("- end - 3:   \(longTimeData[longCount - 3])")
//  print("- end - 2:   \(longTimeData[longCount - 2])")
//  print("- end - 1:   \(longTimeData[longCount - 1])")
  
  let fetchEnd = Date().timeIntervalSince1970
  let fetchMicros = Int((fetchEnd - fetchStart) * 1e6)
  print("fetch: \(fetchMicros) - \(shortTimeData.count) - \(longTimeData.count)")
}
