import PythonKit

extension ImagingWindow {
  func createPlotLabels() {
    let rowLabels: [String] = [
      "current (A)",
      "piezo Z (nm)",
      "XY trajectory (nm)",
    ]
    
    let fourierPlotLabel: String = "Fourier transform"
  }
  
  static func createHistoryPlots(win: PythonObject) -> [HistoryPlot] {
    var output: [HistoryPlot] = []
    
    for rowID in 0..<3 {
      let plot = win.addPlot(row: rowID, col: 0)
      plot.showGrid(x: true, y: true)
      plot.disableAutoRange()
      
      func createCurves() -> [PythonObject] {
        let empty: [Float] = []
        if rowID == 2 {
          func pen(_ color: String) -> PythonObject {
            return pg.mkPen(color, width: 2)
          }
          
          let historyCurve = plot.plot(empty, empty, pen: pen("#2e7ec9"))
          var output = [historyCurve]
          for _ in 0..<Self.maxImagesPerFrame {
            let pixelCurve = plot.plot(empty, empty, pen: pen("orange"))
            output.append(pixelCurve)
          }
          return output
        } else {
          func pen(_ color: String) -> PythonObject {
            return pg.mkPen(color, width: 1)
          }
          
          let minCurve = plot.plot(empty, empty, pen: pen("#1fb864"))
          let avgCurve = plot.plot(empty, empty, pen: pen("orange"))
          let maxCurve = plot.plot(empty, empty, pen: pen("red"))
          return [minCurve, avgCurve, maxCurve]
        }
      }
      
      let curves = createCurves()
      let historyPlot = HistoryPlot(plot: plot, curves: curves)
      output.append(historyPlot)
    }
    
    return output
  }
  
  static func createScanImages(win: PythonObject) -> [[Image]] {
    var output: [[Image]] = []
    for rowID in 0..<2 {
      var imageRow: [Image] = []
      
      for columnID in 0..<2 {
        let plot = win.addPlot(
          row: rowID,
          col: 1 + columnID)
        plot.getViewBox().setAspectLocked(true)
        
        let imageItem = pg.ImageItem()
        plot.addItem(imageItem)
        
        let colorMap = pg.colormap.get("CET-L3")
        let colorBar = pg.ColorBarItem(
          width: 10,
          colorMap: colorMap,
          interactive: false)
        colorBar.setImageItem(imageItem, insert_in: plot)
        
        // For now, don't worry about the problem of color labels consuming
        // excessive space.
        /*
        bar.axis.setStyle(showValues: false)
        bar.axis.setWidth(0)
        
        let labelTop = pg.TextItem(
          "15000",
          color: "w",
          anchor: PythonObject(tupleOf: Float(0.5), Float(1.0)))
        labelTop.setParentItem(bar)
        labelTop.setPos(Int(5), Int(0))
        
        let labelBottom = pg.TextItem(
          "5000",
          color: "w",
          anchor: PythonObject(tupleOf: Float(0.5), Float(0.0)))
        labelBottom.setParentItem(bar)
        labelBottom.setPos(Int(5), Int(100))
        */
        
        let image = Image(
          plot: plot,
          imageItem: imageItem,
          colorBar: colorBar)
        imageRow.append(image)
      }
      output.append(imageRow)
    }
    return output
  }
  
  static func createFourierImage(win: PythonObject) -> Image {
    let plot = win.addPlot(row: 2, col: 2)
    plot.getViewBox().setAspectLocked(true)
    
    let imageItem = pg.ImageItem()
    plot.addItem(imageItem)
    
    let colorMap = pg.colormap.get("CET-L7")
    let colorBar = pg.ColorBarItem(
      width: 10,
      colorMap: colorMap,
      interactive: false)
    colorBar.setImageItem(imageItem, insert_in: plot)
    
    let image = Image(
      plot: plot,
      imageItem: imageItem,
      colorBar: colorBar)
    return image
  }
  
  func linkPlots() {
    let plot0 = historyPlots[0].plot
    let plot1 = historyPlots[1].plot
    plot1.setXLink(plot0)
  }
}
