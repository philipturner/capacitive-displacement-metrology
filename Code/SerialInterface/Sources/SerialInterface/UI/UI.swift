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
  
  var pendingSplittings: [LineParser.Splitting] = []
  
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
    let historyOutput = history.getOutput()
    if historyOutput.longTimeData.count > 0 {
      switch mode {
      case .history:
        historyWindow.update(historyOutput: historyOutput)
      case .imaging:
        let data = historyOutput.longTimeData
        imagingWindow.updateHistoryRanges
        imagingWindow.updatePlots
      }
    }
    
    let output = application.history.getOutput()
    if application.ui.imagingModeActive {
      application.ui.imagingWindow.update(output: output)
    } else {
      application.ui.historyWindow.update(output: output)
    }
    application.ui.showActiveWindows()
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

