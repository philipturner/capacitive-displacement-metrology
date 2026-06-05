struct ImagingState {
  var settings: ImagingSettings
  var pixelTracker: PixelTracker
  
  var receivedPixelCount: Int = 0
  var imageID: Int = 0
  var finishedImages: [[SIMD2<Float>]?] = [nil, nil]
  
  init(settings: ImagingSettings) {
    self.settings = settings
    self.pixelTracker = PixelTracker(settings: settings)
  }
  
  var pixelsPerImage: Int {
    settings.resolution * settings.resolution
  }
  
  mutating func update(lines: [LineParser.Line]) {
    let pixelsPerImage = settings.resolution * settings.resolution
    guard pixelTracker.receivedPixelCount < pixelsPerImage else {
      fatalError("This should never happen.")
    }
    guard receivedPixelCount / pixelsPerImage == imageID else {
      fatalError("This should never happen.")
    }
    
    var remainingPixels = lines
    
    receivedPixelCount += lines.count
  }
}
