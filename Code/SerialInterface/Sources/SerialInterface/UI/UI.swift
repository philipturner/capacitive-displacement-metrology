import PythonKit

class UI {
  let app: PythonObject
  let historyWindow: HistoryWindow
  let imagingWindow: ImagingWindow
  var history: History
  
  enum Mode {
    case history
    case imaging
  }
  private(set) var mode: Mode = .history
  
  init(descriptor: ApplicationDescriptor) {
    pg.setConfigOptions(useOpenGL: true)
    pg.setConfigOptions(antialias: true)
    pg.setConfigOption("imageAxisOrder", "row-major")
    app = QtWidgets.QApplication([String]())
    
    historyWindow = HistoryWindow()
    imagingWindow = ImagingWindow(
      trajectoryLagTime: descriptor.trajectoryLagTime)
    history = History(triggers: descriptor.triggers)
  }
  
  func registerDataCorruptionError() {
    if mode == .imaging {
      fatalError(
        "Encountered corrupted data while imaging mode was active.")
    } else {
      history = History(copying: history)
    }
  }
  
  func reset(modeCode: Int, settingsLines: [LineParser.Line]) {
    if modeCode == 8 {
      mode = .imaging
    } else {
      mode = .history
    }
    
    history = History(copying: history)
    historyWindow.plotsInitialized = false
    imagingWindow.state = ImagingWindow.State()
    
    if mode == .imaging {
      let settings = ImagingSettings(settingsLines: settingsLines)
      imagingWindow.imageHistory = ImageHistory(settings: settings)
    } else {
      imagingWindow.imageHistory = nil
    }
  }
  
  // Must be called on the main thread.
  func update() {
    let output = history.getOutput()
    switch mode {
    case .history:
      historyWindow.update(historyOutput: output)
    case .imaging:
      imagingWindow.update(historyOutput: output)
    }
    
    func canShowHistoryWindow() -> Bool {
      guard mode == .history else {
        return false
      }
      
      if historyWindow.plotsInitialized {
        return true
      } else {
        return false
      }
    }
    
    func canShowImagingWindow() -> Bool {
      guard mode == .imaging else {
        return false
      }
      
      if imagingWindow.state.plotsInitialized,
         imagingWindow.state.imagesInitialized {
        return true
      } else {
        return false
      }
    }
    
    if canShowHistoryWindow() {
      historyWindow.win.show()
    } else {
      historyWindow.win.hide()
    }
    
    if canShowImagingWindow() {
      imagingWindow.win.show()
    } else {
      imagingWindow.win.hide()
    }
  }
}

