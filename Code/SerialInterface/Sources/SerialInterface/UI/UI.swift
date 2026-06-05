import PythonKit

class UI {
  let app: PythonObject
  
  var historyWindow: HistoryWindow
  var imagingWindow: ImagingWindow
  
  init() {
    pg.setConfigOptions(useOpenGL: true)
    pg.setConfigOptions(antialias: true)
    pg.setConfigOption("imageAxisOrder", "row-major")
    app = QtWidgets.QApplication([String]())
    
    historyWindow = HistoryWindow()
    imagingWindow = ImagingWindow()
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
}
