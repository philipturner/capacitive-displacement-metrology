import PythonKit

#if true // Mac
private let windowPositionMac = true
private let rowHeight: Int = 180
private let rowSpacing: Int = 20
private let columnWidth: Int = 350
private let columnSpacing: Int = 20
private let xAxisHeight: Int = 40
private let yAxisWidth: Int = 120
#else // iPad
private let windowPositionMac = false
private let rowHeight: Int = 120
private let rowSpacing: Int = 10
private let columnWidth: Int = 250
private let columnSpacing: Int = 20
private let xAxisHeight: Int = 40
private let yAxisWidth: Int = 120
#endif

extension UI {
  func connectShortcut() {
    let shortcut = QtWidgets.QShortcut(QtGui.QKeySequence("Ctrl+W"), win)
    shortcut.activated.connect(win.close)
  }
  
  func connectWindowCloseEvent() {
    win.closeEvent = PythonFunction { args in
      Application.needsToClose = true
      return Python.None
    }.pythonObject
  }
  
  // Size the window and layout.
  func setupLayout() {
    var x: Int = .zero
    x += yAxisWidth
    x += 2 * columnWidth
    x += columnSpacing + 40
    
    var y: Int = .zero
    y += UI.rowCount * rowHeight
    y += (UI.rowCount - 1) * rowSpacing
    y += xAxisHeight + 10
    
    win.resize(x, y)
    win.ci.layout.setColumnMaximumWidth(0, columnWidth + yAxisWidth)
    win.ci.layout.setColumnMaximumWidth(1, columnWidth)
    
    for rowID in 0..<UI.rowCount {
      win.ci.layout.setRowSpacing(rowID, rowSpacing)
    }
    win.ci.layout.setColumnSpacing(0, columnSpacing)
    win.ci.layout.setColumnSpacing(1, columnSpacing)
  }
  
  // Set the window position on the screen.
  func setWindowPosition() {
    if windowPositionMac {
      win.move(Int(200), Int(20))
    } else {
      win.move(Int(50), Int(0))
    }
  }
  
  func createPlots() {
    for row in 0..<UI.rowCount {
      var plotRow: [PythonObject] = []
      var curveRow: [PythonObject] = []

      for col in 0..<2 {
        let plot = win.addPlot(row: row, col: col)
        plot.showGrid(x: true, y: true)
        plot.disableAutoRange()
        
        func setThickness(axis: PythonObject) {
          let pen = axis.pen()
          pen.setWidth(Self.thicknessFactor)
          axis.setPen(pen)
        }
        
        let xAxis = plot.getAxis("bottom")
        if row == UI.rowCount - 1 {
          plot.setFixedHeight(rowHeight + xAxisHeight)
          xAxis.setHeight(xAxisHeight)
        } else {
          plot.setFixedHeight(rowHeight)
          xAxis.setStyle(showValues: false)
        }
        setThickness(axis: xAxis)
        
        let yAxis = plot.getAxis("left")
        if col == 0 {
          yAxis.setWidth(yAxisWidth)
        } else {
          yAxis.setStyle(showValues: false)
        }
        setThickness(axis: yAxis)
        
        // Create persistent curves
        let emptyArray = [Float]()
        if col == 0 {
          let pen = pg.mkPen("#2e7ec9", width: 2 * Self.thicknessFactor)
          let curve = plot.plot(emptyArray, emptyArray, pen: pen)
          curveRow.append(curve)
        } else {
          func pen(_ color: String) -> PythonObject {
            return pg.mkPen(color, width: Self.thicknessFactor)
          }
          
          let minCurve = plot.plot(emptyArray, emptyArray, pen: pen("#1fb864"))
          let avgCurve = plot.plot(emptyArray, emptyArray, pen: pen("orange"))
          let maxCurve = plot.plot(emptyArray, emptyArray, pen: pen("red"))
          curveRow.append(PythonObject([minCurve, avgCurve, maxCurve]))
        }
        
        plotRow.append(plot)
      }

      plots.append(plotRow)
      curves.append(curveRow)
    }
  }
  
  func linkPlots() {
    // If multiple graphs share a dimension, only set the bounds of one graph
    // and have PyQtGraph make the rest follow it.
    for row in 0..<UI.rowCount {
      plots[row][1].setYLink(plots[row][0])
    }
    for row in 1..<UI.rowCount {
      plots[row][0].setXLink(plots[0][0])
      plots[row][1].setXLink(plots[0][1])
    }
  }
  
  private func createVerticalLabel() -> PythonObject {
    PythonClass(
      "VerticalLabel",
      superclasses: [QtWidgets.QLabel],
      members: [
        "__init__": PythonInstanceMethod { [QtWidgets] args in
          let `self` = args[0]
          guard args.count == 3 else {
            fatalError("Was expecting just the text as an argument.")
          }
          QtWidgets.QLabel.__init__(`self`, args[1], args[2])
          
          return Python.None
        },
        
        "paintEvent": PythonInstanceMethod { [QtGui, QtCore] args in
          let `self` = args[0]
          guard args.count == 2 else {
            fatalError("Was expecting just the event as an argument.")
          }
          
          let painter = QtGui.QPainter(`self`)
          `self`.setAttribute(QtCore.Qt.WA_TranslucentBackground)
          
          painter.translate(`self`.rect().center())
          painter.rotate(-90)
          painter.translate(-`self`.rect().center())
          painter.drawText(`self`.rect(), QtCore.Qt.AlignCenter, `self`.text())
          
          return Python.None
        },
        
        "minimumSizeHint": PythonInstanceMethod { [QtWidgets, QtCore] args in
          let `self` = args[0]
          let size = QtWidgets.QLabel.minimumSizeHint(`self`)
          return QtCore.QSize(size.height(), size.width())
        },
        
        "sizeHint": PythonInstanceMethod { [QtWidgets, QtCore] args in
          let `self` = args[0]
          let size = QtWidgets.QLabel.sizeHint(`self`)
          return QtCore.QSize(size.height(), size.width())
        }
      ]
    ).pythonObject
  }
  
  func createPlotLabels(_ labelTextList: [String]) -> [PythonObject] {
    let VerticalLabel = createVerticalLabel()
    
    var output: [PythonObject] = []
    for labelID in labelTextList.indices {
      let text = labelTextList[labelID]
      let label = VerticalLabel(text, win)
      
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
