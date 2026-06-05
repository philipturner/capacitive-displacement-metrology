struct ImagingState {
  var settings: ImagingSettings
  var pixelTracker: PixelTracker
  
  var receivedPixelCount: Int = 0
  var pendingImages: [[SIMD2<Float>]?] // overwrite to 'nil' after retrieving
  var freezeTrajectory = false
  var trajectorySynchronization: (timestamp: Double, lineID: Int)?
  var deletedHistoryLineCount: Int = 0
  
  init(settings: ImagingSettings) {
    self.settings = settings
    self.pixelTracker = PixelTracker(settings: settings)
    
    let ringBufferSize = (settings.mode == .dualVideo) ? 2 : 1
    self.pendingImages = Array(repeating: nil, count: ringBufferSize)
  }
  
  // Returns a division of lines into different images.
  func split(lines: [LineParser.Line]) -> [[LineParser.Line]] {
    guard lines.count > 0 else {
      return []
    }
    
    func createRowID(line: LineParser.Line) -> Int {
      let pixel = line.values
      guard let pixelID = Int(exactly: pixel[0]) else {
        fatalError("Invalid pixel ID.")
      }
      return pixelID / settings.resolution
    }
    var previousRowID = createRowID(line: lines[0])
    
    var outputSegments: [[LineParser.Line]] = []
    var pendingSegment: [LineParser.Line] = []
    for line in lines {
      let rowID = createRowID(line: line)
      if rowID < previousRowID {
        guard pendingSegment.count > 0 else {
          fatalError("This should never happen.")
        }
        outputSegments.append(pendingSegment)
        pendingSegment = []
      }
      
      pendingSegment.append(line)
      previousRowID = rowID
    }
    if pendingSegment.count > 0 {
      outputSegments.append(pendingSegment)
      pendingSegment = []
    }
    
    func allLinesAccountedFor() -> Bool {
      var outputLineCount: Int = 0
      for segment in outputSegments {
        outputLineCount += segment.count
      }
      return (outputLineCount == lines.count)
    }
    guard allLinesAccountedFor() else {
      fatalError("Something went wrong.")
    }
    return outputSegments
  }
  
  mutating func update(segments: [[LineParser.Line]]) {
    var imageCompleted = false
    for segmentID in segments.indices {
      guard !pixelTracker.isFinished else {
        fatalError("This should never happen.")
      }
      
      let segment = segments[segmentID]
      let imageID = receivedPixelCount / settings.pixelsPerImage
      pixelTracker.receive(
        lines: segment,
        imageID: imageID)
      receivedPixelCount += segment.count
      
      if segmentID < segments.count - 1 {
        guard pixelTracker.isFinished else {
          fatalError("This should never happen.")
        }
        guard receivedPixelCount % settings.pixelsPerImage == 0 else {
          fatalError("Received pixel count not divisible by pixels per image.")
        }
      } else if receivedPixelCount % settings.pixelsPerImage == 0 {
        guard pixelTracker.isFinished else {
          fatalError("This should never happen.")
        }
      }
      
      if pixelTracker.isFinished {
        let ringIndex = imageID % pendingImages.count
        pendingImages[ringIndex] = pixelTracker.dataBuffer
        pixelTracker = PixelTracker(settings: settings)
      }
    }
  }
}
