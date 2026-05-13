import Foundation
import PythonKit
import SwiftSerial

let application = Application.global
await Application.global.initialize()
application.ui = UI() // concurrency <-> Python bug

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

while !Application.global.ui.isClosed {
  let maxFrameRate: Int = 60
  usleep(UInt32(1_000_000 / maxFrameRate))
  
  // TODO: Optionally trigger the short-time acquisition on certain conditions,
  // center the data stream on this point, even if the data set is incomplete.
  // Use a time basis relative to the trigger point, not absolute time (except
  // when trigger is absent).
  //
  // For efficiency, check for the trigger condition while acquiring samples.
  // Then, you know the latest point in time for retrieving in the UI loop.
  //
  // Also, create dedicated functionality for the slow 1-second update mode
  // that reports in absolute time and shows the last n samples.
  var shortTimeDesc = UI.TimeAxisDescriptor()
  shortTimeDesc.length = 0.003
  shortTimeDesc.majorTick = 0.001
  let shortTimeData = Application.global.serialQueue.sync {
    let history = Application.global.history
    return history.sampleHistory(time: shortTimeDesc.length)
  }
  
  var longTimeDesc = UI.TimeAxisDescriptor()
  longTimeDesc.length = 10.0
  longTimeDesc.majorTick = 1.0
  let longTimeData = Application.global.serialQueue.sync {
    let history = Application.global.history
    return history.averageHistory(time: longTimeDesc.length)
  }
  
  guard shortTimeData.count > 0, longTimeData.count > 0 else {
    fatalError("No support for graphing zero-sized data.")
  }
  shortTimeDesc.maximum = shortTimeData.last!.time
  longTimeDesc.maximum = longTimeData.last!.time
  
  let ui = Application.global.ui!
  let shouldDrawShort = getShouldDrawShort(
    latestSampleTime: shortTimeDesc.maximum!)
  
  if shouldDrawShort {
    ui.updateTime(columnID: 0, descriptor: shortTimeDesc)
  }
  ui.updateTime(columnID: 1, descriptor: longTimeDesc)
  
  if shouldDrawShort {
    ui.updateShortPlots(data: shortTimeData)
  }
  ui.updateLongPlots(data: longTimeData)
  
  if shouldDrawShort {
    ui.updateYRange(data: longTimeData)
  }
  
  ui.app.processEvents()
}
