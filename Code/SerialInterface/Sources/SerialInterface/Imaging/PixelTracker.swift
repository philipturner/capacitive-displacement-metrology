struct PixelTracker {
  var settings: ImagingSettings
  var dataBuffer: [SIMD2<Float>]
  var occupiedBuffer: [Bool]
  var receivedPixelCount: Int = 0
  
  init(settings: ImagingSettings) {
    self.settings = settings
    
    let bufferSize = settings.resolution * settings.resolution
    self.dataBuffer = Array(repeating: .zero, count: bufferSize)
    self.occupiedBuffer = Array(repeating: false, count: bufferSize)
  }
  
  var finishedRowCount: Int {
    receivedPixelCount / settings.resolution
  }
  
  mutating func receive(lines: [LineParser.Line], imageID: Int) -> Int {
    var acceptedPixelCount = dataBuffer.count - receivedPixelCount
    acceptedPixelCount = min(acceptedPixelCount, lines.count)
    
    for i in 0..<acceptedPixelCount {
      let pixel = lines[i].values
      guard let pixelID = Int(exactly: pixel[0]) else {
        fatalError("Invalid pixel ID.")
      }
      
      guard pixelID >= 0, pixelID < dataBuffer.count else {
        fatalError("Pixel ID is out of bounds.")
      }
      guard occupiedBuffer[pixelID] == false else {
        fatalError("Pixel is already occupied.")
      }
      
      let rowID = pixelID / settings.resolution
      guard rowID == finishedRowCount else {
        fatalError("Incorrect row for pixel.")
      }
      
      let expectedPosition = settings.expectedPosition(
        pixelID: pixelID,
        imageID: imageID)
      let actualPosition = SIMD2(pixel[1], pixel[2])
      let error = expectedPosition - actualPosition
      let errorMagnitude = (error * error).sum().squareRoot()
      
      let pixelSize = Float(settings.size) / Float(settings.resolution)
      if errorMagnitude < 0.1 * pixelSize {
        
      } else {
        fatalError("""
          Pixel was invalid.
          \(pixel)
          \(imageID)
          """)
      }
      
      let data = SIMD2(abs(pixel[4]), pixel[3])
      dataBuffer[pixelID] = data
      occupiedBuffer[pixelID] = true
      receivedPixelCount += 1
    }
    
    return acceptedPixelCount
  }
}
