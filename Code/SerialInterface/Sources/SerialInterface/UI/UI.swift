import PythonKit

class UI {
  let np: PythonObject
  let pg: PythonObject
  let QtCore: PythonObject
  let QtGui: PythonObject
  let QtWidgets: PythonObject
  
  let app: PythonObject
  let win: PythonObject
  var isClosed = false
  
  static let rowCount: Int = 5
  var plots: [[PythonObject]] = []
  var curves: [[PythonObject]] = []
  var labels: [PythonObject] = []
  
  static let thicknessFactor: Int = 1
  
  init() {
    PythonLibrary.useLibrary(at: "/Users/philipturner/miniforge3/bin/python")
    np = Python.import("numpy")
    pg = Python.import("pyqtgraph")
    QtCore = Python.import("PyQt5.QtCore")
    QtGui = Python.import("PyQt5.QtGui")
    QtWidgets = Python.import("PyQt5.QtWidgets")
    
    pg.setConfigOptions(useOpenGL: true)
    pg.setConfigOptions(antialias: true)
    app = QtWidgets.QApplication([String]())
    win = pg.GraphicsLayoutWidget(show: true)
    
    connectShortcut()
    connectWindowCloseEvent()
    setupLayout()
    setWindowPosition()
    
    // To update labels dynamically at runtime:
    //    for i in 0..<5 {
    //      let labelText = labels[i]
    //      ui.labels[i].setText(labelText)
    //    }
    let labelTextList: [String] = [
      "signal 0",
      "signal 1",
      "signal 2",
      "signal 3",
      "signal 4",
    ]
    createPlots()
    linkPlots()
    labels = createPlotLabels(labelTextList)
  }
}
