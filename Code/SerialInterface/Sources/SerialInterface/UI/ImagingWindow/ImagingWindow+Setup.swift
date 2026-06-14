import PythonKit

private let colorBarAxisWidth: Int = 50
private let rowHeight: Int = 320
private let rowSpacing: Int = 10
private let columnWidthHistory: Int = 420
private let columnWidthImage: Int = 420
private let columnSpacing: Int = 10
private let xAxisHeight: Int = 15
private let yAxisWidthHistory: Int = 100
private let yAxisWidthImage: Int = 50

extension ImagingWindow {
  static let maxImagesPerFrame: Int = 5
  
  func setWindowSize() {
    var x: Int = .zero
    x += yAxisWidthHistory + columnWidthHistory
    x += 2 * (yAxisWidthImage + columnWidthImage)
    x += 2 * columnSpacing
    x += 20
    
    var y: Int = .zero
    y += 3 * (xAxisHeight + rowHeight)
    y += 2 * rowSpacing
    y += 25
    
    win.resize(x, y)
    for columnID in 0..<3 {
      win.ci.layout.setColumnSpacing(columnID, columnSpacing)
    }
    for rowID in 0..<3 {
      win.ci.layout.setRowSpacing(rowID, rowSpacing)
    }
  }
  
  static func setSize(plot: PythonObject, isHistory: Bool) {
    let xAxis = plot.getAxis("bottom")
    plot.setFixedHeight(rowHeight + xAxisHeight)
    xAxis.setHeight(xAxisHeight)
    UI.setThickness(axis: xAxis)
    
    let yAxis = plot.getAxis("left")
    if isHistory {
      plot.setFixedWidth(columnWidthHistory + yAxisWidthHistory)
      yAxis.setWidth(yAxisWidthHistory)
    } else {
      plot.setFixedWidth(columnWidthImage + yAxisWidthImage)
      yAxis.setWidth(yAxisWidthImage)
    }
    UI.setThickness(axis: yAxis)
  }
  
  static func createHistoryPlots(win: PythonObject) -> [HistoryPlot] {
    var output: [HistoryPlot] = []
    
    for rowID in 0..<3 {
      let plot = win.addPlot(row: rowID, col: 0)
      plot.showGrid(x: true, y: true)
      plot.disableAutoRange()
      setSize(plot: plot, isHistory: true)
      
      if rowID == 2 {
        plot.getViewBox().setAspectLocked(true)
      }
      
      func createCurves() -> [PythonObject] {
        let empty: [Float] = []
        if rowID == 2 {
          func pen(_ color: String) -> PythonObject {
            return pg.mkPen(color, width: 2 * UI.thicknessFactor)
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
            return pg.mkPen(color, width: UI.thicknessFactor)
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
  
  static func createScanImagePlots(win: PythonObject) -> [[ImagePlot]] {
    var output: [[ImagePlot]] = []
    for rowID in 0..<2 {
      var imageRow: [ImagePlot] = []
      
      for columnID in 0..<2 {
        let plot = win.addPlot(
          row: rowID,
          col: 1 + columnID)
        plot.getViewBox().setAspectLocked(true)
        setSize(plot: plot, isHistory: false)
        
        let imageItem = pg.ImageItem()
        plot.addItem(imageItem)
        
        let colorMap = pg.colormap.get("CET-L3")
        let colorBar = pg.ColorBarItem(
          width: 10,
          colorMap: colorMap,
          interactive: false)
        colorBar.setImageItem(imageItem, insert_in: plot)
        colorBar.axis.setWidth(colorBarAxisWidth)
        
        let image = ImagePlot(
          plot: plot,
          imageItem: imageItem,
          colorBar: colorBar)
        imageRow.append(image)
      }
      output.append(imageRow)
    }
    return output
  }
  
  static func createFourierImagePlot(win: PythonObject) -> ImagePlot {
    let plot = win.addPlot(row: 2, col: 2)
    plot.getViewBox().setAspectLocked(true)
    setSize(plot: plot, isHistory: false)
    
    let imageItem = pg.ImageItem()
    plot.addItem(imageItem)
    
    let colorMap = pg.colormap.get("CET-L7")
    let colorBar = pg.ColorBarItem(
      width: 10,
      colorMap: colorMap,
      interactive: false)
    colorBar.setImageItem(imageItem, insert_in: plot)
    colorBar.axis.setWidth(colorBarAxisWidth)
    
    let image = ImagePlot(
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
  
  static func createPlotLabels(win: PythonObject) -> [PythonObject] {
    let labelTextList: [String] = [
      "current (pA)",
      "piezo Z (nm)",
      "XY trajectory (nm)",
      "Fourier transform",
    ]
    
    var output: [PythonObject] = []
    for labelID in labelTextList.indices {
      let text = labelTextList[labelID]
      let label = UI.VerticalLabel(text, win)
      
      let boxSize: Int = 500
      label.setStyleSheet("font-size: 20px;")
      label.setFixedSize(boxSize, boxSize)
      label.raise_()
      label.show()
      
      var x: Int = -boxSize / 2
      x += yAxisWidthHistory
      
      if labelID == 3 {
        x += -50
      } else {
        x += -70
      }
      
      if labelID == 3 {
        x += columnWidthHistory
        x += columnSpacing
        
        x += yAxisWidthImage
        x += columnWidthImage
        x += columnSpacing
        
        x += yAxisWidthImage
      }
      
      func getRowID() -> Int {
        if labelID < 3 {
          return labelID
        } else {
          return 2
        }
      }
      var y: Int = -boxSize / 2
      y += getRowID() * (rowHeight + xAxisHeight + rowSpacing)
      y += rowHeight / 2
      y += 12
      
      label.move(x, y)
      
      output.append(label)
    }
    return output
  }
}
