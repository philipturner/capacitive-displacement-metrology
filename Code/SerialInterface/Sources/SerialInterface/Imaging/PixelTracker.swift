struct PixelTracker {
  var settings: ImagingSettings
  var dataBuffer: [SIMD2<Float>]
  var receivedPixelCount: Int = 0
  var statistics: Statistics?
  
  init(settings: ImagingSettings) {
    self.settings = settings
    self.dataBuffer = Array(
      repeating: SIMD2<Float>(-100_000, -1000),
      count: settings._pixelsPerImage)
  }
  
  var receivedRowCount: Int {
    receivedPixelCount / settings._resolutionMajor
  }
  
  var isFinished: Bool {
    guard receivedPixelCount <= settings._pixelsPerImage else {
      fatalError("Received pixel count was too large.")
    }
    return (receivedPixelCount == settings._pixelsPerImage)
  }
  
  mutating func receive(lines: [LineParser.Line], imageID: Int) {
    let nextPixelCount = receivedPixelCount + lines.count
    if nextPixelCount > settings._pixelsPerImage {
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
          let floor = receivedRowCount * settings._resolutionMajor
          let indexInRow = receivedPixelCount - floor
          let output = floor + (settings._resolutionMajor - 1 - indexInRow)
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
        let actualPosition = Self.decodePosition(line: line)
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
      
      let data = SIMD2(line.values[4], line.values[3])
      dataBuffer[pixelID] = data
      receivedPixelCount += 1
    }
  }
  
  static func decodePosition(line: LineParser.Line) -> SIMD2<Float> {
    let encoded = SIMD2<UInt32>(
      line.values[1].bitPattern,
      line.values[2].bitPattern)
    let quantized = SIMD2<Float>(encoded &>> 8)
    
    var output = quantized
    output /= Float(UInt32(1 << 24))
    output *= 512
    output -= 256
    return output
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
    let maxPixelID = receivedRowCount * settings._resolutionMajor
    
    var sum: SIMD2<Double> = .zero
    var minimum = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
    var maximum = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
    for pixelID in 0..<maxPixelID {
      let data = dataBuffer[pixelID]
      sum += SIMD2<Double>(data)
      minimum.replace(with: data, where: data .< minimum)
      maximum.replace(with: data, where: data .> maximum)
    }
    
    let average = SIMD2<Float>(sum) / Float(maxPixelID)
    
    func createStandardDeviation() -> SIMD2<Float> {
      var accumulator: SIMD2<Double> = .zero
      for pixelID in 0..<maxPixelID {
        let data = dataBuffer[pixelID]
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
  
  func split() -> (even: PixelTracker, odd: PixelTracker) {
    var even = self
    var odd = self
    
    for rowID in 0..<settings._resolutionMinor {
      for columnID in 0..<settings._resolutionMajor {
        let pixelID = rowID * settings._resolutionMajor + columnID
        let data = dataBuffer[pixelID]
        
        if rowID % 2 == 0 {
          let overwrittenID = pixelID + settings._resolutionMajor
          even.dataBuffer[overwrittenID] = data
        } else {
          let overwrittenID = pixelID - settings._resolutionMajor
          odd.dataBuffer[overwrittenID] = data
        }
      }
    }
    
    even.updateStatistics()
    odd.updateStatistics()
    
    return (even, odd)
  }
  
  enum Basis {
    case realSpace
    case fourierSpace
  }
  
  func finalized(basis: Basis) -> [SIMD2<Float>] {
    func getFillerPixel() -> SIMD2<Float> {
      switch basis {
      case .realSpace:
        return SIMD2(-100_000, -1000)
      case .fourierSpace:
        return SIMD2(0, 0)
      }
    }
    
    func getSubtractionPixel() -> SIMD2<Float> {
      switch basis {
      case .realSpace:
        return SIMD2(0, 0)
      case .fourierSpace:
        guard let statistics else {
          fatalError("Statistics were not available.")
        }
        return statistics.average
      }
    }
    
    func getPixelsPerImage() -> Int {
      if basis == .fourierSpace, !ImagingWindow.useZeroPaddedFourierImage {
        return settings._pixelsPerImage
      } else {
        let resolution = settings._resolutionMajor
        return resolution * resolution
      }
    }
    
    var output = [SIMD2<Float>](
      repeating: getFillerPixel(),
      count: getPixelsPerImage())
    
    let boundary = (settings._resolutionMajor - settings._resolutionMinor) / 2
    let subtractionPixel = getSubtractionPixel()
    
    for rowID in 0..<settings._resolutionMinor {
      for columnID in 0..<settings._resolutionMajor {
        let pixelID = rowID * settings._resolutionMajor + columnID
        var data = dataBuffer[pixelID]
        data -= subtractionPixel
        
        func getSlotID() -> Int {
          if basis == .fourierSpace, !ImagingWindow.useZeroPaddedFourierImage {
            if settings.majorAxis == 0 {
              return rowID * settings._resolutionMajor + columnID
            } else {
              return columnID * settings._resolutionMinor + rowID
            }
          } else {
            let mappedRowID = boundary + rowID
            if settings.majorAxis == 0 {
              return mappedRowID * settings._resolutionMajor + columnID
            } else {
              return columnID * settings._resolutionMajor + mappedRowID
            }
          }
        }
        let slotID = getSlotID()
        output[slotID] = data
      }
    }
    return output
  }
}
