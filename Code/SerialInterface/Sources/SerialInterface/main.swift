import Foundation
import PythonKit
import SwiftSerial

let application = Application()
Application.queue.sync {
  var trigger = Trigger()
  trigger.type = .level(0)
  trigger.polarity = .positive
  trigger.channel = 1
  application.history.trigger = trigger
}

while !application.ui.isClosed {
  let maxFrameRate: Int = 60
  usleep(UInt32(1_000_000 / maxFrameRate))
  
  let shortTimeLength: Double = 0.003
  let shortTimeMajorTick: Double = 0.001
  let longTimeLength: Double = 1.0
  let longTimeMajorTick: Double = 0.2
  
  let shortTimeData = Application.queue.sync {
    application.history.sampleHistory(time: shortTimeLength)
  }
  let longTimeData = Application.queue.sync {
    application.history.averageHistory(time: longTimeLength)
  }
  let triggerEventTrace = Application.queue.sync {
    let time = shortTimeLength / 2
    return application.history.triggerEventTrace(
      bipolarHistoryTime: time)
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
    application.ui.updateTime(columnID: 0, descriptor: shortTimeDesc)
  }
  func updateLongTime() {
    let maximum = longTimeData.last!.time
    
    var longTimeDesc = UI.TimeAxisDescriptor()
    longTimeDesc.minimum = maximum - longTimeLength
    longTimeDesc.maximum = maximum
    longTimeDesc.majorTick = longTimeMajorTick
    application.ui.updateTime(columnID: 1, descriptor: longTimeDesc)
  }
  func updateShortTimeForTrigger(
    data: [History.TimedSample],
    timeInterval: SIMD2<Double>
  ) {
    var shortTimeDesc = UI.TimeAxisDescriptor()
    shortTimeDesc.minimum = timeInterval[0]
    shortTimeDesc.maximum = timeInterval[1]
    shortTimeDesc.majorTick = shortTimeMajorTick
    
    let triggerType = application.history.trigger.type
    if case .timeInterval(_, let offset) = triggerType {
      shortTimeDesc.offset = offset
    } else {
      let offset = (timeInterval[0] + timeInterval[1]) / 2
      shortTimeDesc.offset = offset
    }
    
    application.ui.updateTime(columnID: 0, descriptor: shortTimeDesc)
  }
  
  updateLongTime()
  application.ui.updateLongPlots(data: longTimeData)
  application.ui.updateYRange(data: longTimeData)
  
  if let triggerEventTrace {
    updateShortTimeForTrigger(
      data: triggerEventTrace.data,
      timeInterval: triggerEventTrace.timeInterval)
    application.ui.updateShortPlots(
      data: triggerEventTrace.data)
  } else {
    print("[\(Date())] No trigger event trace.")
    updateShortTimeForHistory()
    application.ui.updateShortPlots(data: shortTimeData)
  }
  
  application.ui.app.processEvents()
}
