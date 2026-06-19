import Foundation
import PythonKit

extension ImagingWindow {
  static let ImageRelativeGridItem = createImageRelativeGridItem()
  
  static func createImageRelativeGridItem() -> PythonObject {
    PythonClass(
      "ImageRelativeGridItem",
      superclasses: [pg.GridItem],
      members: [
        "__init__": PythonInstanceMethod { args in
          let `self` = args[0]
          pg.GridItem.__init__(`self`)
          
          let imageItem = args[1]
          `self`.imageItem = imageItem
          
          let pen = pg.mkPen(
            "c",
            width: 3,
            cosmetic: true)
          `self`.gridPen = pen
          
          return Python.None
        },
        
        "paint": PythonInstanceMethod { args in
          let `self` = args[0]
          let painter = args[1]
          painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing, false)
          painter.setPen(`self`.gridPen)
          
          let imageRect = `self`.imageItem.boundingRect()
          let transform = `self`.imageItem.transform()
          
          let resolution = Int(exactly: Float(imageRect.width())!)!
          let pixelDimension = Float(transform.m11())!
          let lowerLeft = SIMD2(
            Float(transform.dx())!,
            Float(transform.dy())!)
          let upperRight = lowerLeft + pixelDimension * Float(resolution)
          
          let segmentCount: Int = 6
          
          for rowID in 0...segmentCount {
            var lineX = Float(rowID) / Float(segmentCount)
            lineX *= Float(resolution)
            lineX *= pixelDimension
            lineX += lowerLeft[0]
            
            painter.drawLine(
              QtCore.QPointF(lineX, lowerLeft[1]),
              QtCore.QPointF(lineX, upperRight[1]))
          }
          
          for columnID in 0...segmentCount {
            var lineY = Float(columnID) / Float(segmentCount)
            lineY *= Float(resolution)
            lineY *= pixelDimension
            lineY += lowerLeft[1]
            
            painter.drawLine(
              QtCore.QPointF(lowerLeft[0], lineY),
              QtCore.QPointF(upperRight[0], lineY))
          }
          
          painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing, true)
          return Python.None
        }
      ]
    ).pythonObject
  }
}
