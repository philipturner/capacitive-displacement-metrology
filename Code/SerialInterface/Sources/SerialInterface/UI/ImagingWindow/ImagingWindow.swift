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
  
  struct TrajectoryState {
    var deletedLineCount: Int = 0
    var frozen: Bool = false
    var synchronization: (timestamp: Double, lineID: Int)?
    var historyLines: [LineParser.Line] = []
    var pixelLines: [LineParser.Line] = []
  }
  
  struct State {
    var plotsInitialized = false
    var imagesInitialized = false
    var trajectory = TrajectoryState()
  }
  
  let win: PythonObject
  let trajectoryLagTime: Double?
  var state = State()
  
  var historyPlots: [HistoryPlot]
  var scanImages: [[Image]]
  var fourierImage: Image
  var labels: [PythonObject]
  
  var imageHistory: ImageHistory!
  
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
    let settings = ImagingSettings(settingsLines: settingsLines)
    s = ImagingWindowState()
    imagingState = ImagingState(settings: settings)
    pendingHistoryLines = []
    pendingPixelLines = []
    
    // Do not access Python from the background thread.
    // updateFourierImageVisibility()
    // resetImages()
  }
  
  func update() {
    
  }
}
