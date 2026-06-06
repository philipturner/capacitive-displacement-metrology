import PythonKit

class UI {
  let app: PythonObject
  
  var imagingModeActive: Bool = false
  var historyWindow: HistoryWindow
  var imagingWindow: ImagingWindow
  
  static let thicknessFactor: Int = 1
  
  init(trajectoryLagTime: Double?) {
    pg.setConfigOptions(useOpenGL: true)
    pg.setConfigOptions(antialias: true)
    pg.setConfigOption("imageAxisOrder", "row-major")
    app = QtWidgets.QApplication([String]())
    
    historyWindow = HistoryWindow()
    imagingWindow = ImagingWindow(trajectoryLagTime: trajectoryLagTime)
  }
  
  static func connectCloseShortcut(win: PythonObject) {
    let shortcut = QtWidgets.QShortcut(QtGui.QKeySequence("Ctrl+W"), win)
    
    let closeEvent = PythonFunction { args in
      Application.needsToClose = true
      return Python.None
    }.pythonObject
    
    // Makes the application close when "Ctrl + W" is typed, and the window
    // 'win' is in focus.
    shortcut.activated.connect(closeEvent)
    
    // Makes the application close after pressing the red button to close the
    // window.
    win.closeEvent = closeEvent
  }
  
  func showActiveWindows() {
    if !imagingModeActive, historyWindow.plotDataValid {
      historyWindow.win.show()
    } else {
      historyWindow.win.hide()
    }
    
    if imagingModeActive, imagingWindow.plotDataValid {
      imagingWindow.win.show()
    } else {
      imagingWindow.win.hide()
    }
  }
}
