import Foundation
import PythonKit
import SwiftSerial

let ui = UI()
let application = Application.global
await Application.global.initialize()

// Set the trigger type.
Application.global.serialQueue.sync {
  let history = application.history
  _ = history.trigger
}

let startTime = Date().timeIntervalSince1970
while !ui.isClosed {
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
  let shortTimeMajorTick: Double = 0.001
  let longTimeLength: Double = 10.0
  let longTimeMajorTick: Double = 1.0
  let shortTimeData = Application.global.serialQueue.sync {
    let history = Application.global.history
    return history.sampleHistory(time: shortTimeLength)
  }
  let longTimeData = Application.global.serialQueue.sync {
    let history = Application.global.history
    return history.averageHistory(time: longTimeLength)
  }
  let triggerEventTrace = Application.global.serialQueue.sync {
    let history = Application.global.history
    let time = shortTimeLength / 2
    return history.triggerEventTrace(bipolarHistoryTime: time)
  }
  guard shortTimeData.count > 0, longTimeData.count > 0 else {
    fatalError("No serial data was received.")
  }
  
  func updateShortTimeForHistory() {
    let maximum = shortTimeData.last!.time
    
    var shortTimeDesc = UI.TimeAxisDescriptor()
    shortTimeDesc.minimum = maximum - shortTimeLength
    shortTimeDesc.maximum = maximum
    shortTimeDesc.majorTick = shortTimeMajorTick
    ui.updateTime(columnID: 0, descriptor: shortTimeDesc)
  }
  func updateLongTime() {
    let maximum = longTimeData.last!.time
    
    var longTimeDesc = UI.TimeAxisDescriptor()
    longTimeDesc.minimum = maximum - longTimeLength
    longTimeDesc.maximum = maximum
    longTimeDesc.majorTick = longTimeMajorTick
    ui.updateTime(columnID: 1, descriptor: longTimeDesc)
  }
  func updateShortTimeForTrigger(
    data: [History.TimedSample],
    timeInterval: SIMD2<Double>
  ) {
    var shortTimeDesc = UI.TimeAxisDescriptor()
    shortTimeDesc.minimum = timeInterval[0]
    shortTimeDesc.maximum = timeInterval[1]
    shortTimeDesc.majorTick = shortTimeMajorTick
    
    let history = Application.global.history
    let triggerType = history.trigger.type
    if case .timeInterval(_, let offset) = triggerType {
      shortTimeDesc.offset = offset
    } else {
      let offset = (timeInterval[0] + timeInterval[1]) / 2
      shortTimeDesc.offset = offset
    }
    
    ui.updateTime(columnID: 0, descriptor: shortTimeDesc)
  }
  
  updateLongTime()
  ui.updateLongPlots(data: longTimeData)
  
  let currentTime = Date().timeIntervalSince1970
  if currentTime - startTime < 1 {
    if let triggerEventTrace {
      print("Did get the trigger event trace.")
    } else {
      print("No event trace..")
    }
  }
  
  ui.app.processEvents()
}
