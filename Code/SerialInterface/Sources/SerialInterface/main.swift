import Foundation
import PythonKit
import SwiftSerial

var trigger = Trigger()
//trigger.type = .level(0)
//trigger.polarity = .positive
//trigger.channel = 1

var applicationDesc = ApplicationDescriptor()
applicationDesc.triggers = [trigger]
let application = Application(descriptor: applicationDesc)
Watchdog.initialize(trackedThreads: 2)

func display(start: Double, end: Double) {
  let timeInMs = (end - start) * 1000
  let formattedTime = String(format: "%.3f", timeInMs)
  print(formattedTime, "ms")
}

var nextLoopTime = Date().timeIntervalSince1970
var previousLoopTime = nextLoopTime
while !application.ui.isClosed {
  let currentTime = Date().timeIntervalSince1970
  if currentTime > nextLoopTime {
    print()
    print("time since last previous loop start:")
    display(start: previousLoopTime, end: currentTime)
    
    previousLoopTime = currentTime
    while currentTime > nextLoopTime {
      nextLoopTime += 16.666e-3
    }
  } else {
    usleep(1_000)
    continue
  }
  Watchdog.notify(threadID: 0, code: 0)
  
  let time0 = Date().timeIntervalSince1970
  
  let shortTimeLength: Double = 0.003
  let shortTimeMajorTick: Double = 0.001
  let longTimeLength: Double = 1.0
  let longTimeMajorTick: Double = 0.2
  
  let output = Application.queue.sync {
    return application.history.output(
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
  
  let time1 = Date().timeIntervalSince1970
  
  updateLongTime()
  application.ui.updateLongPlots(
    data: output.longTimeData)
  application.ui.updateYRange(
    data: output.longTimeData)
  
  print(output.shortTimeData.last!.values[3])
  
  if let trace = output.trace {
    updateShortTimeForTrigger(trace: trace)
    application.ui.updateShortPlots(
      data: trace.data)
  } else {
    updateShortTimeForHistory()
    application.ui.updateShortPlots(
      data: output.shortTimeData)
  }
  
  let time2 = Date().timeIntervalSince1970
  
  application.ui.app.processEvents()
  
  let time3 = Date().timeIntervalSince1970
  
  print("segments:")
  display(start: time0, end: time1)
  display(start: time1, end: time2)
  display(start: time2, end: time3)
}
