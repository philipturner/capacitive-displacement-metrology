import Foundation
import PythonKit
import SwiftSerial

var trigger = Trigger()
trigger.type = .level(0)
trigger.polarity = .positive
trigger.channel = 1

var applicationDesc = ApplicationDescriptor()
applicationDesc.trigger = trigger
let application = Application(descriptor: applicationDesc)

while !application.ui.isClosed {
  let maxFrameRate: Int = 60
  usleep(UInt32(1_000_000 / maxFrameRate))
  
  let shortTimeLength: Double = 0.003
  let shortTimeMajorTick: Double = 0.001
  let longTimeLength: Double = 1.0
  let longTimeMajorTick: Double = 0.2
  
  let output = Application.queue.sync {
    application.history.output(
      shortInterval: shortTimeLength,
      longInterval: longTimeLength)
  }
  guard output.shortTimeData.count > 0,
        output.longTimeData.count > 0 else {
    print("[\(Date())] No data to graph.")
    continue
  }
  
  func updateShortTimeForHistory() {
    let maximum = output.shortTimeData.last!.time
    
    var shortTimeDesc = UI.TimeAxisDescriptor()
    shortTimeDesc.minimum = maximum - shortTimeLength
    shortTimeDesc.maximum = maximum
    shortTimeDesc.majorTick = shortTimeMajorTick
    application.ui.updateTime(columnID: 0, descriptor: shortTimeDesc)
  }
  func updateLongTime() {
    let maximum = output.longTimeData.last!.time
    
    var longTimeDesc = UI.TimeAxisDescriptor()
    longTimeDesc.minimum = maximum - longTimeLength
    longTimeDesc.maximum = maximum
    longTimeDesc.majorTick = longTimeMajorTick
    application.ui.updateTime(columnID: 1, descriptor: longTimeDesc)
  }
  func updateShortTimeForTrigger(
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
  application.ui.updateLongPlots(
    data: output.longTimeData)
  application.ui.updateYRange(
    data: output.longTimeData)
  
  if let trace = output.trace {
    updateShortTimeForTrigger(
      timeInterval: trace.timeInterval)
    application.ui.updateShortPlots(
      data: trace.data)
  } else {
    print("[\(Date())] No trigger event trace.")
    updateShortTimeForHistory()
    application.ui.updateShortPlots(
      data: output.shortTimeData)
  }
  
  application.ui.app.processEvents()
}
