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
  
  static let rowCount: Int = 4
  var plots: [[PythonObject]] = []
  var curves: [[PythonObject]] = []
  
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
    
    let labelTextList: [String] = [
      "current (pA)",
      "sample bias (V)",
      "capacitance (fF)",
      "phase shift (°)",
    ]
    createPlots()
    linkPlots()
    createPlotLabels(labelTextList)
  }
}
