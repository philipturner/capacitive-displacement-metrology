import Foundation
import PythonKit

class ImagingWindow {
  static let maxImagesPerFrame: Int = 5
  var trajectoryLagTime: Double?
  
  let win: PythonObject
  var plotDataValid = false
  
  struct HistoryPlot {
    var plot: PythonObject
    var curves: [PythonObject]
  }
  
  struct Image {
    var plot: PythonObject
    var imageItem: PythonObject
    var colorBar: PythonObject
  }
  
  var historyPlots: [HistoryPlot]
  var scanImages: [[Image]]
  var fourierImage: Image
  var labels: [PythonObject]
  
  var state: ImagingState!
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
  
  func reset(settingsLines: [LineParser.Line]) {
    guard pendingSettingsLines.count == 2 else {
      let lineCount = pendingSettingsLines.count
      fatalError(
        "Invalid number of pending settings lines: \(lineCount)")
    }
    
    var values: [Float] = []
    for i in 0..<5 {
      let line = pendingSettingsLines[0]
      values.append(line.values[i])
    }
    for i in 0..<3 {
      let line = pendingSettingsLines[1]
      values.append(line.values[i])
    }
    
    let settings = ImagingSettings(values: values)
    state = ImagingState(settings: settings)
    
    pendingSettingsLines = []
    pendingHistoryLines = []
    pendingPixelLines = []
  }
}
