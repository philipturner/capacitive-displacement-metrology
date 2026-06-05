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
  TimeAxis.shortLength = 0.010
  TimeAxis.longLength = 3
  
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.pythonLibraryPath = "/Users/philipturner/miniforge3/bin/python"
  applicationDesc.triggers = [createTrigger1()]
  applicationDesc.useEmulator = true
  return Application(descriptor: applicationDesc)
}
let application = createApplication()

application.run {
  Application.queue.sync {
    if application.imagingModeActive {
      application.ui.historyWindow.win.hide()
      application.ui.imagingWindow.win.show()
    } else {
      application.ui.historyWindow.win.show()
      application.ui.imagingWindow.win.hide()
    }
    
    let output = application.history.getOutput()
    if application.imagingModeActive {
      
    } else {
      application.ui.historyWindow.update(output: output)
    }
  }
}
