import PythonKit

class HistoryWindow {
  let win: PythonObject
  
  var plots: [[PythonObject]] = []
  var curveSets: [[PythonObject]] = []
  var labels: [PythonObject] = []
  
  var shortPlotsInitialized: Bool = false
  var longPlotsInitialized: Bool = false
  
  init() {
    win = pg.GraphicsLayoutWidget(show: true)
    win.move(Int(0), Int(0))
    UI.connectCloseShortcut(win: win)
    
    let labelTextList: [String] = [
      "signal 0",
      "signal 1",
      "signal 2",
      "signal 3",
      "signal 4",
    ]
    labels = createPlotLabels(labelTextList)
    
    createPlots()
    linkPlots()
    setWindowSize()
  }
}
