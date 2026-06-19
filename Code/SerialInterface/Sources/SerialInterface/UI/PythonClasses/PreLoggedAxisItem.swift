import func Foundation.pow
import PythonKit

extension ImagingWindow {
  // TODO: Make the setpoint current passed into the python object at runtime
  
  static let PreLoggedAxisItem = createPreLoggedAxisItem()
  
  static func createPreLoggedAxisItem() -> PythonObject {
    PythonClass(
      "PreLoggedAxisItem",
      superclasses: [pg.AxisItem],
      members: [
        "tickStrings": PythonInstanceMethod { args in
          let `self` = args[0]
          let values = args[1]
          let scale = args[2]
          let spacing = args[3]
          
          guard let useLogScale = Bool(`self`.useLogScale),
                let setpoint = Float(`self`.setpoint) else {
            fatalError("Did not set parameters for pre-logged axis item.")
          }
          
          if !useLogScale {
            return pg.AxisItem.tickStrings(`self`, values, scale, spacing)
          }
          
          let valuesDouble = [Double](values)
          guard let valuesDouble else {
            fatalError("Failed data type conversion")
          }
          
          return valuesDouble.map { originalValue in
            let exponentValue = pow(10, originalValue)
            
            if setpoint < 100 {
              return String(format: "%.1f", exponentValue)
            } else {
              let rounded = Int(exponentValue.rounded(.toNearestOrEven))
              return String(rounded)
            }
          }
        }
      ]
    ).pythonObject
  }
}
