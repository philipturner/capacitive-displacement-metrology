enum ImagingMode: UInt8 {
  case image = 0
  case video = 1
  case dualVideo = 2
}

struct ImagingSettings {
  var mode: ImagingMode
  var resolution: Int
  var size: Float
  var centers: [SIMD2<Float>]
  var setpointCurrent: Float
  
  init(values: [Float]) {
    guard values.count == 8 else {
      fatalError("Invalid number of values.")
    }
    
    guard let rawValue = UInt8(exactly: values[0]),
          let mode = ImagingMode(rawValue: rawValue) else {
      fatalError("Invalid mode.")
    }
    self.mode = mode
    
    guard let resolution = Int(exactly: values[1]),
          resolution > 0,
          resolution % 2 == 0 else {
      fatalError("Invalid resolution.")
    }
    self.resolution = resolution
    
    self.size = values[2]
    
    self.centers = [
      SIMD2(values[3], values[4]),
      SIMD2(values[5], values[6]),
    ]
    
    self.setpointCurrent = values[7]
  }
}
