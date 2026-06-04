import Foundation
import PythonKit

class ImagingWindow {
  let win: PythonObject
  
  var plots: [[PythonObject]] = []
  
  init() {
    win = pg.GraphicsLayoutWidget(show: true)
    win.move(Int(200), Int(20))
    setWindowSize()
    UI.connectCloseShortcut(win: win)
    
    createPlots()
    
    createPlotLabels()
  }
  
  func setWindowSize() {
    
  }
  
  func createPlots() {
    for rowID in 0..<3 {
      var plotRow: [PythonObject] = []
      
      for columnID in 0..<3 {
        if rowID == 2, columnID == 1 {
          continue
        }
        let plot = win.addPlot(row: rowID, col: columnID)
        if rowID <= 1, columnID >= 1 {
          
        } else {
          plot.showGrid(x: true, y: true)
        }
//         plot.disableAutoRange()
        
        if rowID == 1, columnID == 1 {
          let arrayDimension = PythonObject(tupleOf: Int(100), Int(100))
          var data = np.zeros(shape: arrayDimension, dtype: np.float32)
          for i in 0..<100 {
            for j in 0..<100 {
              var output: Float = 1 + 0.3 * sin(Float(i))
              output *= Float(i) * Float(i)
              output += Float(j) * Float(j)
              output *= 1 + 0.2 * Float.random(in: 0..<1)
              
              data[i, j] = PythonObject(output)
            }
          }
          
          let img = pg.ImageItem(image: data)
          let pixelSize: Float = 0.1
          let startPosition = SIMD2<Float>(-2, -3)
          
          let transform = QtGui.QTransform()
          transform.scale(pixelSize, pixelSize)
          transform.translate(
            startPosition[0] / pixelSize,
            startPosition[1] / pixelSize)
          img.setTransform(transform)
          
          plot.getViewBox().setAspectLocked(true)
          plot.addItem(img)
          
          let cm = pg.colormap.get("CET-L9")
          let values = PythonObject(tupleOf: Float(0), Float(20000))
          let bar = pg.ColorBarItem(
            values: values,
            width: 10,
            colorMap: cm,
            interactive: false)
          bar.setImageItem(img, insert_in: plot)
          bar.axis.setStyle(showValues: false)
          bar.axis.setWidth(0)
          
          let labelTop = pg.TextItem(
            "20000",
            color: "w",
            anchor: PythonObject(tupleOf: Float(0.5), Float(1.0)))
          labelTop.setParentItem(bar)
          labelTop.setPos(Int(5), Int(0))
          
          let labelBottom = pg.TextItem(
            "0",
            color: "w",
            anchor: PythonObject(tupleOf: Float(0.5), Float(0.0)))
          labelBottom.setParentItem(bar)
          labelBottom.setPos(Int(5), Int(100))
        }
        
        plotRow.append(plot)
      }
      
      plots.append(plotRow)
    }
  }
  
  func createPlotLabels() {
    let rowLabels: [String] = [
      "current (A)",
      "piezo Z (nm)",
      "XY trajectory (nm)",
    ]
    
    let fourierPlotLabel: String = "Fourier transform"
  }
}
