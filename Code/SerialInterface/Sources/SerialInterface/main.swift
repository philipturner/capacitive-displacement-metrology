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
  TimeAxis.longLength = 2.5
  
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.pythonLibraryPath = "/Users/philipturner/miniforge3/bin/python"
  applicationDesc.trajectoryLagTime = 0.1
  applicationDesc.triggers = [createTrigger1()]
  return Application(descriptor: applicationDesc)
}
let application = createApplication()

application.run {
  Application.queue.sync {
    application.ui.update()
  }
}
