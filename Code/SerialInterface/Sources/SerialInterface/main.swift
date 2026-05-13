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
  // Use a time basis relative to the trigger point (0 = center) for certain
  // types of triggers.
  //
  // For efficiency, check for the trigger condition while acquiring samples.
  // Then, you know the latest point in time for retrieving in the UI loop.
  //
  // Also, create dedicated functionality for the slow 1-second update mode
  // that reports in absolute time and shows the last n samples.
  
  let shortTimeLength: Double = 0.003
  let longTimeLength: Double = 10.0
  let shortTimeData = Application.global.serialQueue.sync {
    let history = Application.global.history
    return history.sampleHistory(time: shortTimeLength)
  }
  let longTimeData = Application.global.serialQueue.sync {
    let history = Application.global.history
    return history.averageHistory(time: longTimeLength)
  }
  guard shortTimeData.data.count > 0, longTimeData.count > 0 else {
    fatalError("No support for graphing zero-sized data.")
  }
  
  func updateShortTime() {
    var shortTimeDesc = UI.TimeAxisDescriptor()
    shortTimeDesc.minimum = shortTimeData.timeInterval[0]
    shortTimeDesc.maximum = shortTimeData.timeInterval[1]
    shortTimeDesc.majorTick = 0.001
    
    let history = Application.global.history
    let triggerType = history.trigger.type
    if case .timeInterval(let period, let offset) = triggerType {
      shortTimeDesc.offset = offset
    } else {
      let interval = shortTimeData.timeInterval
      let offset = (interval[0] + interval[1]) / 2
      shortTimeDesc.offset = offset
    }
    
    ui.updateTime(columnID: 0, descriptor: shortTimeDesc)
  }
  func updateLongTime() {
    let maximum = longTimeData.last!.time
    
    var longTimeDesc = UI.TimeAxisDescriptor()
    longTimeDesc.minimum = maximum - longTimeLength
    longTimeDesc.maximum = maximum
    longTimeDesc.majorTick = 1.0
    ui.updateTime(columnID: 1, descriptor: longTimeDesc)
  }
  
  let ui = Application.global.ui!
  let shouldDrawShort = getShouldDrawShort(
    latestSampleTime: shortTimeData.timeInterval[1])
  
  updateLongTime()
  ui.updateLongPlots(data: longTimeData)
  
  if shouldDrawShort {
    updateShortTime()
    ui.updateShortPlots(data: shortTimeData.data)
    ui.updateYRange(data: longTimeData)
  }
  
  ui.app.processEvents()
}
