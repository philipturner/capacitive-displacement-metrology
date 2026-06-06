import PythonKit

class HistoryWindow {
  let win: PythonObject
  var plotDataValid = false
  
  static let rowCount: Int = 5
  var plots: [[PythonObject]] = []
  var curveSets: [[PythonObject]] = []
  var labels: [PythonObject] = []
  
  init() {
    win = pg.GraphicsLayoutWidget(show: true)
    setWindowPosition()
    setWindowSize()
    UI.connectCloseShortcut(win: win)
    
    createPlots()
    linkPlots()
    
    let labelTextList: [String] = [
      "signal 0",
      "signal 1",
      "signal 2",
      "signal 3",
      "signal 4",
    ]
    labels = createPlotLabels(labelTextList)
  }
}
