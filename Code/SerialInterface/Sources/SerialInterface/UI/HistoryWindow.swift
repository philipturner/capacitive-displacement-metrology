import PythonKit

class HistoryWindow {
  let win: PythonObject
  
  static let rowCount: Int = 5
  var plots: [[PythonObject]] = []
  var curves: [[PythonObject]] = []
  var labels: [PythonObject] = []
  
  static let thicknessFactor: Int = 1
  
  init() {
    win = pg.GraphicsLayoutWidget(show: true)
    
    connectShortcut()
    setupLayout()
    setWindowPosition()
    
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
