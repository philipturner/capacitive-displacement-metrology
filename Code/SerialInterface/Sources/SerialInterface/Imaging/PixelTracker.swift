struct PixelTracker {
  static let rejectOddRows: Bool = true
  static let overrideCurrentData: Bool = false
  
  var settings: ImagingSettings
  var dataBuffer: [SIMD2<Float>]
  var receivedPixelCount: Int = 0
  var statistics: Statistics?
  
  init(settings: ImagingSettings) {
    self.settings = settings
    
    let fillerPixel = SIMD2<Float>(-100_000, -1000)
    dataBuffer = Array(
      repeating: fillerPixel,
      count: settings.pixelsPerImage)
  }
  
  var receivedRowCount: Int {
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
      func createPixelID() -> Int {
        let bitPattern = line.values[0].bitPattern
        return Int(bitPattern >> 8)
      }
      let pixelID = createPixelID()
      
      func createExpectedPixelID() -> Int {
        if receivedRowCount % 2 == 0 {
          return receivedPixelCount
        } else {
          let floor = receivedRowCount * settings.resolution
          let indexInRow = receivedPixelCount - floor
          let output = floor + (settings.resolution - 1 - indexInRow)
          return output
        }
      }
      let expectedPixelID = createExpectedPixelID()
      guard pixelID == expectedPixelID else {
        fatalError("""
          Incorrect pixel ID.
          expected: \(expectedPixelID)
          got: \(pixelID)
          """)
      }
      
      func checkErrorMagnitude() {
        let expectedPosition = settings.expectedPosition(
          pixelID: pixelID,
          imageID: imageID)
        let actualPosition = SIMD2(line.values[1], line.values[2])
        let error = actualPosition - expectedPosition
        let errorMagnitude = (error * error).sum().squareRoot()
        
        if errorMagnitude > 0.1 * settings.pixelDimension {
          fatalError("""
            Incorrect pixel position.
            expected: \(expectedPosition)
            got: \(actualPosition)
            """)
        }
      }
      checkErrorMagnitude()
      
      var data = SIMD2(line.values[4], line.values[3])
      if Self.overrideCurrentData {
        let position = SIMD2(line.values[1], line.values[2])
        let normalizedCurrent = Emulator.normalizedCurrent(position: position)
        let current = normalizedCurrent * settings.setpointCurrent
        data[0] = current
      }
      receivedPixelCount += 1
      
      if Self.rejectOddRows {
        let rowID = pixelID / settings.resolution
        guard rowID % 2 == 0 else {
          continue
        }
      }
      
      // If rejecting even rows, write the latest row and then overwrite data
      // on the next odd row.
      let slotID = settings.bufferSlotID(pixelID: pixelID)
      dataBuffer[slotID] = data
      
      // [move the above guard statement here]
      
      if Self.rejectOddRows {
        let overwrittenPixelID = pixelID - settings.resolution
        let slotID = settings.bufferSlotID(pixelID: overwrittenPixelID)
        dataBuffer[slotID] = data
      }
    }
  }
}

extension PixelTracker {
  struct Statistics {
    var average: SIMD2<Float>
    var stddev: SIMD2<Float>
    var minimum: SIMD2<Float>
    var maximum: SIMD2<Float>
  }
  
  mutating func updateStatistics() {
    guard receivedRowCount > 0 else {
      return
    }
    let maxPixelID = receivedRowCount * settings.resolution
    
    var sum: SIMD2<Double> = .zero
    var minimum = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
    var maximum = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
    for pixelID in 0..<maxPixelID {
      let slotID = settings.bufferSlotID(pixelID: pixelID)
      let data = dataBuffer[slotID]
      sum += SIMD2<Double>(data)
      minimum.replace(with: data, where: data .< minimum)
      maximum.replace(with: data, where: data .> maximum)
    }
    
    let average = SIMD2<Float>(sum) / Float(maxPixelID)
    
    func createStandardDeviation() -> SIMD2<Float> {
      var accumulator: SIMD2<Double> = .zero
      for pixelID in 0..<maxPixelID {
        let slotID = settings.bufferSlotID(pixelID: pixelID)
        let data = dataBuffer[slotID]
        let deviation = data - average
        let deviationSquared = deviation * deviation
        accumulator += SIMD2<Double>(deviationSquared)
      }
      
      var output = SIMD2<Float>(accumulator)
      output /= Float(maxPixelID)
      output.formSquareRoot()
      return output
    }
    let stddev = createStandardDeviation()
    
    statistics = Statistics(
      average: average,
      stddev: stddev,
      minimum: minimum,
      maximum: maximum)
  }
}
