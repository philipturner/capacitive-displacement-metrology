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

Watchdog.initialize(trackedThreads: 2)

while !application.ui.isClosed {
  let time0 = Date().timeIntervalSince1970
  
  Watchdog.notify(threadID: 0, code: 0)
  usleep(10_000)
  Watchdog.notify(threadID: 0, code: 1)
  
  let time1 = Date().timeIntervalSince1970
  
  let shortTimeLength: Double = 0.003
  let shortTimeMajorTick: Double = 0.001
  let longTimeLength: Double = 1.0
  let longTimeMajorTick: Double = 0.2
  
  var time2: Double = .zero
  var time3: Double = .zero
  
  let output = Application.queue.sync {
    time2 = Date().timeIntervalSince1970
    Watchdog.notify(threadID: 0, code: 2)
    let output = application.history.output(
      shortInterval: shortTimeLength,
      longInterval: longTimeLength)
    Watchdog.notify(threadID: 0, code: 3)
    time3 = Date().timeIntervalSince1970
    return output
  }
  guard output.shortTimeData.count > 0,
        output.longTimeData.count > 0 else {
    print("[\(Date())] No data to graph.")
    continue
  }
  Watchdog.notify(threadID: 0, code: 4)
  
  let time4 = Date().timeIntervalSince1970
  
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
  Watchdog.notify(threadID: 0, code: 5)
  
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
  Watchdog.notify(threadID: 0, code: 6)
  
  let time5 = Date().timeIntervalSince1970
  
  application.ui.app.processEvents()
  Watchdog.notify(threadID: 0, code: 7)
  
  let time6 = Date().timeIntervalSince1970
  
  func display(start: Double, end: Double) {
    let timeInMs = (end - start) * 1000
    let formattedTime = String(format: "%.1f", timeInMs)
    print(formattedTime, "ms")
  }
  
  print()
  display(start: time0, end: time1)
  display(start: time1, end: time2)
  display(start: time2, end: time3)
  display(start: time3, end: time4)
  display(start: time4, end: time5)
  display(start: time5, end: time6)
  print("overall:")
  display(start: time0, end: time6)
}
