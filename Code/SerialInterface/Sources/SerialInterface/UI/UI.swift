import PythonKit

class UI {
  let app: PythonObject
  
  // TODO: Encapsulate all the variables below into "Oscilloscope" and "Imaging"
  // windows, separate code for each.
  let win: PythonObject
  
  static let rowCount: Int = 5
  var plots: [[PythonObject]] = []
  var curves: [[PythonObject]] = []
  var labels: [PythonObject] = []
  
  static let thicknessFactor: Int = 1
  
  init() {
    pg.setConfigOptions(useOpenGL: true)
    pg.setConfigOptions(antialias: true)
    app = QtWidgets.QApplication([String]())
    win = pg.GraphicsLayoutWidget(show: true)
    
    connectShortcut()
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
