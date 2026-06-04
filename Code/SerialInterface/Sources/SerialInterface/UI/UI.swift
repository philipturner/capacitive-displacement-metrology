import PythonKit

class UI {
  let app: PythonObject
  
  var historyWindow: HistoryWindow
  
  init() {
    pg.setConfigOptions(useOpenGL: true)
    pg.setConfigOptions(antialias: true)
    app = QtWidgets.QApplication([String]())
    
    historyWindow = HistoryWindow()
  }
}
