import Foundation
import PythonKit

class ImagingWindow {
  static let useLogScaleCurrentImage: Bool = false
  static let useSplitImages: Bool = true
  
  struct HistoryPlot {
    var plot: PythonObject
    var curves: [PythonObject]
  }
  
  struct ImagePlot {
    var plot: PythonObject
    var imageItem: PythonObject
    var colorBar: PythonObject
    var gridItem: PythonObject?
  }
  
  struct TrajectoryState {
    var deletedLineCount: Int = 0
    var synchronization: (timestamp: Double, lineID: Int)?
    var historyLines: [LineParser.Line] = []
    var pixelLines: [LineParser.Line] = []
  }
  
  struct State {
    var currentAndZPlotsInitialized = false
    var trajectoryPlotInitialized = false
    var imagesInitialized = false
    var trajectory = TrajectoryState()
    var lastImageStatistics: PixelTracker.Statistics?
  }
  
  let win: PythonObject
  let trajectoryLagTime: Double?
  var state = State()
  
  var historyPlots: [HistoryPlot]
  var scanImagePlots: [[ImagePlot]]
  var fourierImagePlots: [ImagePlot]
  var labels: [PythonObject]
  
  var imageHistory: ImageHistory!
  var settings: ImagingSettings { imageHistory.settings }
  
  init(trajectoryLagTime: Double?) {
    self.trajectoryLagTime = trajectoryLagTime
    
    win = pg.GraphicsLayoutWidget(show: true)
    win.move(Int(0), Int(0))
    UI.connectCloseShortcut(win: win)
    
    historyPlots = Self.createHistoryPlots(win: win)
    scanImagePlots = Self.createScanImagePlots(win: win)
    fourierImagePlots = Self.createFourierImagePlots(win: win)
    labels = Self.createPlotLabels(win: win)
    
    linkPlots()
    setWindowSize()
  }
  
  func update(history: History) {
    drawCurrentAndZPlots(history: history)
    drawTrajectoryPlot(history: history)
    
    if !state.imagesInitialized {
      updateFourierImageVisibility()
      updateGridVisibility()
      updateColorBarAxes()
      resetImages()
      state.imagesInitialized = true
    }
    
    imageHistory.update(lines: state.trajectory.pixelLines)
    updateImages()
    
    removePendingData()
  }
  
  func removeOldHistoryLines(lagTime: Double) {
    if state.trajectory.synchronization == nil {
      if state.trajectory.historyLines.count > 0 {
        let timestamp = Date().timeIntervalSince1970
        let lineID = state.trajectory.historyLines.count
        state.trajectory.synchronization = (timestamp, lineID)
      }
    }
    
    if let synchronization = state.trajectory.synchronization {
      let currentTime = Date().timeIntervalSince1970
      let pastTime = currentTime - lagTime
      let deltaTime = pastTime - synchronization.timestamp
      
      let timePerLine = 1e-6 * Double(History.logPeriodMicros)
      let deltaLines = Int(deltaTime / timePerLine)
      var maxLineID = synchronization.lineID + deltaLines
      maxLineID -= state.trajectory.deletedLineCount
      
      if maxLineID > 0 {
        let currentLineCount = state.trajectory.historyLines.count
        let deletedLineCount = min(maxLineID, currentLineCount)
        state.trajectory.historyLines.removeFirst(deletedLineCount)
        state.trajectory.deletedLineCount += deletedLineCount
      }
    }
  }
  
  func removePendingData() {
    if let trajectoryLagTime {
      removeOldHistoryLines(lagTime: trajectoryLagTime)
    } else {
      state.trajectory.historyLines = []
    }
    state.trajectory.pixelLines = []
    
    if imageHistory.settings.mode != .image {
      for i in imageHistory.pendingImages.indices {
        imageHistory.pendingImages[i] = nil
      }
    }
  }
}
