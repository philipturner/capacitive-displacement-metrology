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
  
  var plots: [HistoryPlot]
  var scanImages: [[Image]]
  var fourierImage: Image
  var labels: [PythonObject]
  
  var imageHistory: ImageHistory!
  var settings: ImagingSettings { imageHistory.settings }
  
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
  
  func update(historyOutput: History.Output) {
    if historyOutput.longTimeData.count > 0 {
      updatePlots(data: historyOutput.longTimeData)
      state.plotsInitialized = true
    }
    
    if !state.imagesInitialized {
      updateFourierImageVisibility()
      resetImages()
      state.imagesInitialized = true
    }
    
    imageHistory.update(lines: state.trajectory.pixelLines)
    updateScanImages()
    updateFourierImage()
    
    let pixelSegments = state.split(lines: pendingPixelLines)
    state.update(lines: pixelSegments)
    for i in state.pendingImages.indices {
      state.pendingImages[i] = nil
    }
    
    if let trajectoryLagTime {
      removeOldHistoryLines(lagTime: trajectoryLagTime)
    } else {
      state.trajectory.historyLines = []
    }
    state.trajectory.pixelLines = []
    
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
}
