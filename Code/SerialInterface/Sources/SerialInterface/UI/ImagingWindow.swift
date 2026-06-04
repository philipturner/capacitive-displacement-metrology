import PythonKit

class ImagingWindow {
  let win: PythonObject
  
  init() {
    win = pg.GraphicsLayoutWidget(show: true)
    win.move(Int(200), Int(20))
    setWindowSize()
    UI.connectCloseShortcut(win: win)
  }
  
  func setWindowSize() {
    
  }
}
