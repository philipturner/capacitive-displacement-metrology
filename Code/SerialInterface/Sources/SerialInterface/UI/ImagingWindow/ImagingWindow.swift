import Foundation
import PythonKit

class ImagingWindow {
  struct HistoryPlot {
    var plot: PythonObject
    var curves: [PythonObject]
  }
  
  struct Image {
    var plot: PythonObject
    var imageItem: PythonObject
    var colorBar: PythonObject
  }
  
  struct State {
    var deletedHistoryLineCount: Int = 0
    var freezeTrajectory = false
    var trajectorySynchronization: (timestamp: Double, lineID: Int)?
  }
  
  let win: PythonObject
  let trajectoryLagTime: Double?
  var state = State()
  
  var historyPlots: [HistoryPlot]
  var scanImages: [[Image]]
  var fourierImage: Image
  var labels: [PythonObject]
  
  var imageHistory: ImageHistory!
  var pendingHistoryLines: [LineParser.Line] = []
  var pendingPixelLines: [LineParser.Line] = []
  
  init(trajectoryLagTime: Double?) {
    self.trajectoryLagTime = trajectoryLagTime
    
    win = pg.GraphicsLayoutWidget(show: true)
    win.move(Int(0), Int(0))
    UI.connectCloseShortcut(win: win)
    
    historyPlots = Self.createHistoryPlots(win: win)
    scanImages = Self.createScanImages(win: win)
    fourierImage = Self.createFourierImage(win: win)
    labels = Self.createPlotLabels(win: win)
    
    linkPlots()
    setWindowSize()
  }
  
  func stop() {
    state = State()
    imageHistory = nil
  }
  
  func start(settingsLines: [LineParser.Line]) {
    guard !active else {
      fatalError("Attempted to activate when already activated.")
    }
    active = true
    
    let settings = ImagingSettings(settingsLines: settingsLines)
    windowState = ImagingWindowState()
    imagingState = ImagingState(settings: settings)
    pendingHistoryLines = []
    pendingPixelLines = []
    
    // Do not access Python from the background thread.
    // updateFourierImageVisibility()
    // resetImages()
  }
}
