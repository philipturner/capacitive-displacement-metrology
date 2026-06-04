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

func createApplication() -> Application {
  var historyDesc = HistoryDescriptor()
  historyDesc.shortTimeLength = 0.010
  historyDesc.longTimeLength = 3
  historyDesc.triggers = [createTrigger1()]

  var applicationDesc = ApplicationDescriptor()
  applicationDesc.historyDescriptor = historyDesc
  applicationDesc.pythonLibraryPath = "/Users/philipturner/miniforge3/bin/python"
  applicationDesc.useEmulator = true
  return Application(descriptor: applicationDesc)
}
let application = createApplication()

application.run {
  #if false
  let timeAxis = Application.queue.sync {
    // Solution to Swift bug that is extremely hard to reproduce?
    // The code has not crashed unexpectedly since I implemented this change.
    application.history.timeAxis
  }
  let output = Application.queue.sync {
    return application.history.output(
      shortInterval: timeAxis.shortLength,
      longInterval: timeAxis.longLength)
  }
  guard output.shortTimeData.count > 0,
        output.longTimeData.count > 0 else {
    return
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
    data: output.longTimeData)
  
  if let trace = output.trace {
    updateShortTimeForTrigger(trace: trace)
    application.ui.updateShortPlots(
      data: trace.data)
  } else {
    updateShortTimeForHistory()
    application.ui.updateShortPlots(
      data: output.shortTimeData)
  }
  #endif
}
