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
          
          let pen = pg.mkPen(width: UI.thicknessFactor, cosmetic: true)
          `self`.gridPen = pen
          
          return Python.None
        },
        
        "paint": PythonInstanceMethod { args in
          let `self` = args[0]
          let painter = args[1]
          painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing, false)
          painter.setPen(`self`.gridPen)
          
          let imageRect = `self`.imageItem.boundingRect()
          let imageSize = SIMD2(
            Float(imageRect.width())!,
            Float(imageRect.height())!)
          let imageStartCoords = SIMD2(
            Float(imageRect.left())!,
            Float(imageRect.top())!)
          
          let viewRect = `self`.getViewBox().viewRect()
          let viewStartCoords = SIMD2(
            Float(viewRect.left())!,
            Float(viewRect.top())!)
          let viewEndCoords = SIMD2(
            Float(viewRect.right())!,
            Float(viewRect.bottom())!)
          
          let transform = `self`.imageItem.transform()
          print(transform)
          print("dx", transform.dx())
          print("dy", transform.dy())
          print("m11", transform.m11())
          print("m22", transform.m22())
          print("m12", transform.m12())
          print("m21", transform.m21())
          print("m13", transform.m13())
          print("m23", transform.m23())
          print("m33", transform.m33())
          
          let segmentCount: Int = 6
          
          for rowID in 0...segmentCount {
            var localX = Float(rowID) / Float(segmentCount)
            localX *= imageSize[0]
            localX += imageStartCoords[0]
            
            let pointArgument = QtCore.QPointF(localX, imageStartCoords[1])
            let mappedPoint = transform[dynamicMember: "map"](pointArgument)
            let lineX = Float(mappedPoint.x)!
            
            
            print("rendering \(rowID) | \(viewStartCoords[0]) \(localX) \(viewEndCoords[0])")
            guard viewStartCoords[0] <= lineX,
                  lineX <= viewEndCoords[0] else {
              continue
            }
            
            
            
            painter.drawLine(
              QtCore.QPointF(lineX, viewStartCoords[1]),
              QtCore.QPointF(lineX, viewEndCoords[1]))
          }
          
          painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing, true)
          return Python.None
        }
      ]
    ).pythonObject
  }
}
