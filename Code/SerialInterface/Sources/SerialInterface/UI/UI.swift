import PythonKit

class UI {
  enum Mode {
    case history
    case imaging
  }
  
  let app: PythonObject
  let historyWindow: HistoryWindow
  let imagingWindow: ImagingWindow
  private(set) var mode: Mode = .history
  
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
  
  func changeMode(_ mode: Mode) {
    if mode == .history {
      historyWindow.plotsInitialized = false
    }
  }
  
  func showActiveWindows() {
    var showHistoryWindow = false
    var showImagingWindow = false
    
    if imagingModeActive {
      
    } else {
      if historyWindow.plotsInitialized {
        showHistoryWindow = true
      }
    }
    
    
    if !imagingModeActive, historyWindow.plotsInitialized {
      historyWindow.win.show()
    } else {
      historyWindow.win.hide()
    }
    
    func canShowImagingWindow() {
      
    }
    
    if imagingModeActive, imagingWindow.plotDataValid {
      imagingWindow.win.show()
    } else {
      imagingWindow.win.hide()
    }
  }
}
