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
  
  func setWindowSize() {
    
  }
  
  func createPlotLabels() {
    let rowLabels: [String] = [
      "current (pA)", // we will change units on the host side
      "piezo Z (nm)",
      "XY trajectory (nm)",
    ]
    
    let fourierPlotLabel: String = "Fourier transform"
  }
}
