import Foundation
import PythonKit
import SwiftSerial

await Application.global.initialize()
let ui = UI()

// Set the trigger type.
Application.global.serialQueue.sync {
//  let history = Application.global.history
//  history.trigger.type = .derivative(dx: 100, dt: 100e-6)
//  history.trigger.polarity = .positive
//  history.trigger.channel = 0
}

while !ui.isClosed {
  let maxFrameRate: Int = 60
  usleep(UInt32(1_000_000 / maxFrameRate))
  
  let shortTimeLength: Double = 0.003
  let shortTimeMajorTick: Double = 0.001
  let longTimeLength: Double = 10.0
  let longTimeMajorTick: Double = 2.0
  
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
  ui.updateYRange(data: longTimeData)
  
  if let triggerEventTrace {
    updateShortTimeForTrigger(
      data: triggerEventTrace.data,
      timeInterval: triggerEventTrace.timeInterval)
    ui.updateShortPlots(
      data: triggerEventTrace.data)
  } else {
    print("[\(Date())] No trigger event trace.")
    updateShortTimeForHistory()
    ui.updateShortPlots(data: shortTimeData)
  }
  
  ui.app.processEvents()
}
