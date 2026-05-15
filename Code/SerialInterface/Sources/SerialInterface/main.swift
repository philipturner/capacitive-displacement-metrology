import Foundation
import PythonKit
import SwiftSerial

#if true
var trigger = Trigger()
trigger.type = .level(0)
trigger.polarity = .positive
trigger.channel = 1

#else
var trigger1 = Trigger()
trigger1.type = .level(700)
trigger1.polarity = .positive
trigger1.channel = 0

var trigger2 = Trigger()
trigger2.type = .level(-700)
trigger2.polarity = .negative
trigger2.channel = 0
#endif

var applicationDesc = ApplicationDescriptor()
applicationDesc.triggers = [trigger]
let application = Application(descriptor: applicationDesc)

Watchdog.initialize(trackedThreads: 2)

while !application.ui.isClosed {
  let shortTimeLength: Double = 0.003
  let shortTimeMajorTick: Double = 0.001
  let longTimeLength: Double = 1.0
  let longTimeMajorTick: Double = 0.2
  
  let time0 = Date().timeIntervalSince1970
  var time1: Double = .zero
  var time2: Double = .zero
  Watchdog.notify(threadID: 0, code: 0)
  
  let output = Application.queue.sync {
    time1 = Date().timeIntervalSince1970
    Watchdog.notify(threadID: 0, code: 1)
    
    let output = application.history.output(
      shortInterval: shortTimeLength,
      longInterval: longTimeLength)
    
    time2 = Date().timeIntervalSince1970
    Watchdog.notify(threadID: 0, code: 2)
    
    return output
  }
  guard output.shortTimeData.count > 0,
        output.longTimeData.count > 0 else {
    print("[\(Date())] No data to graph.")
    usleep(20_000)
    continue
  }
  let time3 = Date().timeIntervalSince1970
  Watchdog.notify(threadID: 0, code: 3)
  
  do {
    let dt = time2 - time0
    if dt < 10e-3 {
      usleep(5_000)
    }
  }
  let time4 = Date().timeIntervalSince1970
  Watchdog.notify(threadID: 0, code: 4)
  
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
    trace: History.TriggerEventTrace
  ) {
    var shortTimeDesc = UI.TimeAxisDescriptor()
    shortTimeDesc.minimum = trace.timeInterval[0]
    shortTimeDesc.maximum = trace.timeInterval[1]
    shortTimeDesc.majorTick = shortTimeMajorTick
    
    if case .timeInterval(_, let offset) = trace.trigger.type {
      shortTimeDesc.offset = offset
    } else {
      let offset = (trace.timeInterval[0] + trace.timeInterval[1]) / 2
      shortTimeDesc.offset = offset
    }
    
    application.ui.updateTime(columnID: 0, descriptor: shortTimeDesc)
  }
  
  updateLongTime()
  application.ui.updateLongPlots(
    data: output.longTimeData)
  application.ui.updateYRange(
    data: output.longTimeData)
  let time5 = Date().timeIntervalSince1970
  Watchdog.notify(threadID: 0, code: 5)
  
  if let trace = output.trace {
    updateShortTimeForTrigger(
      trace: trace)
    application.ui.updateShortPlots(
      data: trace.data)
  } else {
    print("[\(Date())] No trigger event trace.")
    updateShortTimeForHistory()
    application.ui.updateShortPlots(
      data: output.shortTimeData)
  }
  let time6 = Date().timeIntervalSince1970
  Watchdog.notify(threadID: 0, code: 6)
  
  application.ui.app.processEvents()
  let time7 = Date().timeIntervalSince1970
  Watchdog.notify(threadID: 0, code: 7)
  
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
  display(start: time6, end: time7)
  print("overall:")
  display(start: time0, end: time7)
}
