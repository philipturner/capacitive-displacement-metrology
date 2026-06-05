import Foundation
import PythonKit

class ImagingWindow {
  let win: PythonObject
  
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
  
  var pendingSettingsLines: [LineParser.Line] = []
  var settings: ImagingSettings?
  
  init() {
    win = pg.GraphicsLayoutWidget(show: true)
    win.move(Int(200), Int(20))
    UI.connectCloseShortcut(win: win)
    
    historyPlots = Self.createHistoryPlots(win: win)
    scanImages = Self.createScanImages(win: win)
    fourierImage = Self.createFourierImage(win: win)
    
    for imageRow in scanImages {
      for image in imageRow {
        Self.updateScan(image: image)
      }
    }
    Self.updateFourier(image: fourierImage)
  }
  
  func reset() {
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
    settings = ImagingSettings(values: values)
  }
}
