import PythonKit

extension UI {
  static let VerticalLabel = PythonClass(
    "VerticalLabel",
    superclasses: [QtWidgets.QLabel],
    members: [
      "__init__": PythonInstanceMethod { args in
        let `self` = args[0]
        guard args.count == 3 else {
          fatalError("Was expecting just the text as an argument.")
        }
        QtWidgets.QLabel.__init__(`self`, args[1], args[2])
        
        return Python.None
      },
      
      "paintEvent": PythonInstanceMethod { args in
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
      
      "minimumSizeHint": PythonInstanceMethod { args in
        let `self` = args[0]
        let size = QtWidgets.QLabel.minimumSizeHint(`self`)
        return QtCore.QSize(size.height(), size.width())
      },
      
      "sizeHint": PythonInstanceMethod { args in
        let `self` = args[0]
        let size = QtWidgets.QLabel.sizeHint(`self`)
        return QtCore.QSize(size.height(), size.width())
      }
    ]
  ).pythonObject
}
