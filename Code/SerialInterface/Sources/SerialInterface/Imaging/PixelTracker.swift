struct PixelTracker {
  var settings: ImagingSettings
  
  // TODO: Initialize empty pixels to [-100_000, -1000]
  // TODO: Invert Y axis and convert from A to pA here
  // TODO: Accumulate the min, max, mean, variance (<x^2> - <x>^2) on
  // the fly as pixels are added
  var dataBuffer: [SIMD2<Float>]
  var occupiedBuffer: [Bool]
  var receivedPixelCount: Int = 0
  
  init(settings: ImagingSettings) {
    self.settings = settings
    self.dataBuffer = Array(
      repeating: .zero,
      count: settings.pixelsPerImage)
    self.occupiedBuffer = Array(
      repeating: false,
      count: settings.pixelsPerImage)
  }
  
  var finishedRowCount: Int {
    receivedPixelCount / settings.resolution
  }
  
  var isFinished: Bool {
    guard receivedPixelCount <= settings.pixelsPerImage else {
      fatalError("Received pixel count was too large.")
    }
    return (receivedPixelCount == settings.pixelsPerImage)
  }
  
  mutating func receive(lines: [LineParser.Line], imageID: Int) {
    let nextPixelCount = receivedPixelCount + lines.count
    if nextPixelCount > settings.pixelsPerImage {
      fatalError("Requesting too many lines for pixel tracker.")
    }
    
    for line in lines {
      let pixel = line.values
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
      
      #if false
      let pixelSize = Float(settings.size) / Float(settings.resolution)
      if errorMagnitude < 0.1 * pixelSize {
        
      } else {
        fatalError("""
          Pixel was invalid.
          \(pixel)
          \(imageID)
          """)
      }
      #endif
      
      let data = SIMD2(abs(pixel[4]), pixel[3])
      if rowID % 2 == 0 {
        dataBuffer[pixelID] = data
        dataBuffer[pixelID + settings.resolution] = data
      }
      occupiedBuffer[pixelID] = true
      receivedPixelCount += 1
    }
  }
}
