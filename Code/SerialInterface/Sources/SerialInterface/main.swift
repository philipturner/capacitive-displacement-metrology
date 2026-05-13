import Foundation
import PythonKit
import SwiftSerial

await Application.global.initialize()

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
  
  var shortTimeDesc = UI.TimeAxisDescriptor()
  shortTimeDesc.length = 0.003
  shortTimeDesc.majorTick = 0.001
  let shortTimeData = Application.global.serialQueue.sync {
    let history = Application.global.history
    return history.sampleHistory(time: shortTimeDesc.length)
  }
  
  var longTimeDesc = UI.TimeAxisDescriptor()
  longTimeDesc.length = 10.0
  longTimeDesc.majorTick = 1.0
  let longTimeData = Application.global.serialQueue.sync {
    let history = Application.global.history
    return history.averageHistory(time: longTimeDesc.length)
  }
  
  guard shortTimeData.count > 0, longTimeData.count > 0 else {
    fatalError("No support for graphing zero-sized data.")
  }
  shortTimeDesc.maximum = shortTimeData.last!.time
  longTimeDesc.maximum = longTimeData.last!.time
  
  let ui = Application.global.ui
  let shouldDrawShort = getShouldDrawShort(
    latestSampleTime: shortTimeDesc.maximum!)
  
  if shouldDrawShort {
    ui.updateTime(columnID: 0, descriptor: shortTimeDesc)
  }
  ui.updateTime(columnID: 1, descriptor: longTimeDesc)
  
  if shouldDrawShort {
    ui.updateShortPlots(data: shortTimeData)
  }
  ui.updateLongPlots(data: longTimeData)
  
  if shouldDrawShort {
    ui.updateYRange(data: longTimeData)
  }
  
  ui.app.processEvents()
}
