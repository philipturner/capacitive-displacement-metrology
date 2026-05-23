import Foundation
import PythonKit
import SwiftSerial

func createTrigger1() -> Trigger {
  var trigger = Trigger()
  trigger.type = .timeInterval(period: 0.5, offset: 0)
  trigger.polarity = .signAgnostic
  trigger.channel = 0
  return trigger
}

var historyDesc = HistoryDescriptor()
historyDesc.shortTimeLength = 0.050
historyDesc.longTimeLength = 5
historyDesc.triggers = [createTrigger1()]

var applicationDesc = ApplicationDescriptor()
applicationDesc.historyDescriptor = historyDesc
let application = Application(descriptor: applicationDesc)
Watchdog.initialize(trackedThreads: 2)

var nextLoopTime = Date().timeIntervalSince1970
while !application.ui.isClosed {
  let currentTime = Date().timeIntervalSince1970
  if currentTime > nextLoopTime {
    while currentTime > nextLoopTime {
      nextLoopTime += 16.666e-3
    }
  } else {
    usleep(1_000)
    continue
  }
  Watchdog.notify(threadID: 0, code: 0)
  
  let input = Application.queue.sync {
    if application.inputForMainThread.count > 0 {
      return application.inputForMainThread.removeFirst()
    } else {
      return ""
    }
  }
  application.commandTransmitter.updateLabels(
    input, ui: application.ui)
  
  let timeAxis = application.history.timeAxis
  let output = Application.queue.sync {
    return application.history.output(
      shortInterval: timeAxis.shortLength,
      longInterval: timeAxis.longLength)
  }
  guard output.shortTimeData.count > 0,
        output.longTimeData.count > 0 else {
    // print("[\(Date())] No data to graph.")
    continue
  }
  
  func updateShortTimeForHistory() {
    let maximum = output.shortTimeData.last!.time
    
    var shortTimeDesc = UI.TimeAxisDescriptor()
    shortTimeDesc.minimum = maximum - timeAxis.shortLength
    shortTimeDesc.maximum = maximum
    shortTimeDesc.majorTick = timeAxis.shortMajorTick
    application.ui.updateTime(columnID: 0, descriptor: shortTimeDesc)
  }
  func updateLongTime() {
    let maximum = output.longTimeData.last!.time
    
    var longTimeDesc = UI.TimeAxisDescriptor()
    longTimeDesc.minimum = maximum - timeAxis.longLength
    longTimeDesc.maximum = maximum
    longTimeDesc.majorTick = timeAxis.longMajorTick
    application.ui.updateTime(columnID: 1, descriptor: longTimeDesc)
  }
  func updateShortTimeForTrigger(
    trace: History.TriggerEventTrace
  ) {
    var shortTimeDesc = UI.TimeAxisDescriptor()
    shortTimeDesc.minimum = trace.timeInterval[0]
    shortTimeDesc.maximum = trace.timeInterval[1]
    shortTimeDesc.majorTick = timeAxis.shortMajorTick
    
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
    data: output.longTimeData,
    lifetimes: SIMD4(5, 5, 2, 5))
  
  if let trace = output.trace {
    updateShortTimeForTrigger(trace: trace)
    application.ui.updateShortPlots(
      data: trace.data)
  } else {
    updateShortTimeForHistory()
    application.ui.updateShortPlots(
      data: output.shortTimeData)
  }
  
  application.ui.app.processEvents()
}
