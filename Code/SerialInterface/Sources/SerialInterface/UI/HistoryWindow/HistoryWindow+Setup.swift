import PythonKit

#if true // Mac
private let rowHeight: Int = 180
private let rowSpacing: Int = 20
private let columnWidth: Int = 350
private let columnSpacing: Int = 20
private let xAxisHeight: Int = 40
private let yAxisWidth: Int = 120
#else // iPad
private let rowHeight: Int = 120
private let rowSpacing: Int = 10
private let columnWidth: Int = 200
private let columnSpacing: Int = 20
private let xAxisHeight: Int = 40
private let yAxisWidth: Int = 120
#endif

extension HistoryWindow {
  func setWindowSize() {
    var x: Int = .zero
    x += yAxisWidth
    x += 2 * columnWidth
    x += columnSpacing + 40
    
    var y: Int = .zero
    y += Self.rowCount * rowHeight
    y += (Self.rowCount - 1) * rowSpacing
    y += xAxisHeight + 10
    
    win.resize(x, y)
    win.ci.layout.setColumnMaximumWidth(0, columnWidth + yAxisWidth)
    win.ci.layout.setColumnMaximumWidth(1, columnWidth)
    
    for rowID in 0..<Self.rowCount {
      win.ci.layout.setRowSpacing(rowID, rowSpacing)
    }
    win.ci.layout.setColumnSpacing(0, columnSpacing)
    win.ci.layout.setColumnSpacing(1, columnSpacing)
  }
  
  func createPlots() {
    for rowID in 0..<Self.rowCount {
      var plotRow: [PythonObject] = []
      var curveRow: [PythonObject] = []

      for columnID in 0..<2 {
        let plot = win.addPlot(row: rowID, col: columnID)
        plot.showGrid(x: true, y: true)
        plot.disableAutoRange()
        
        let xAxis = plot.getAxis("bottom")
        if rowID == Self.rowCount - 1 {
          plot.setFixedHeight(rowHeight + xAxisHeight)
          xAxis.setHeight(xAxisHeight)
        } else {
          plot.setFixedHeight(rowHeight)
          xAxis.setStyle(showValues: false)
        }
        UI.setThickness(axis: xAxis)
        
        let yAxis = plot.getAxis("left")
        if columnID == 0 {
          yAxis.setWidth(yAxisWidth)
        } else {
          yAxis.setStyle(showValues: false)
        }
        UI.setThickness(axis: yAxis)
        
        // Create persistent curves
        let emptyArray = [Float]()
        if columnID == 0 {
          let pen = pg.mkPen("#2e7ec9", width: 2 * UI.thicknessFactor)
          let curve = plot.plot(emptyArray, emptyArray, pen: pen)
          curveRow.append(curve)
        } else {
          func pen(_ color: String) -> PythonObject {
            return pg.mkPen(color, width: UI.thicknessFactor)
          }
          
          let minCurve = plot.plot(emptyArray, emptyArray, pen: pen("#1fb864"))
          let avgCurve = plot.plot(emptyArray, emptyArray, pen: pen("orange"))
          let maxCurve = plot.plot(emptyArray, emptyArray, pen: pen("red"))
          curveRow.append(PythonObject([minCurve, avgCurve, maxCurve]))
        }
        
        plotRow.append(plot)
      }

      plots.append(plotRow)
      curveSets.append(curveRow)
    }
  }
  
  func linkPlots() {
    // If multiple graphs share a dimension, only set the bounds of one graph
    // and have PyQtGraph make the rest follow it.
    for row in 0..<Self.rowCount {
      plots[row][1].setYLink(plots[row][0])
    }
    for row in 1..<Self.rowCount {
      plots[row][0].setXLink(plots[0][0])
      plots[row][1].setXLink(plots[0][1])
    }
  }
  
  func createPlotLabels(_ labelTextList: [String]) -> [PythonObject] {
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
      x += yAxisWidth
      x += -90
      
      var y: Int = -boxSize / 2
      y += labelID * (rowHeight + rowSpacing)
      y += rowHeight / 2
      y += 12
      
      label.move(x, y)
      
      output.append(label)
    }
    return output
  }
}
