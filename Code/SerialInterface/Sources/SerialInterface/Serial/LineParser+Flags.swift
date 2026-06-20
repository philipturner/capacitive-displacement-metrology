extension LineParser {
  enum Flags: UInt8, CaseIterable {
    case modeChange = 0
    case kilohertzLoopWarning = 1
    case invalidCommand = 2
    
    case history = 10
    case historyDiscard = 11
    case spectroscopy = 12
    case imaging = 13
    case imagingSettings = 14
    case creepSettings = 15
    case tiltCalculation = 16
    case tiltSettings = 17
  }
  
  struct Splitting {
    var newModeCode: Int?
    var data: [[Line]]
    
    init() {
      let element = [Line]()
      let count = Flags.allCases.count
      data = Array(repeating: element, count: count)
    }
    
    subscript(index: Flags) -> [Line] {
      _read {
        let slotID = Int(index.rawValue)
        yield data[slotID]
      }
      _modify {
        let slotID = Int(index.rawValue)
        yield &data[slotID]
      }
    }
    
    // Displays a subset of the lines.
    func display() {
      for line in self[.spectroscopy] {
        print("spectroscopy", terminator: ", ")
        for laneID in 0..<5 {
          let value = line.values[laneID]
          print(value, terminator: ", ")
        }
        print()
      }
      
      for line in self[.tilt] {
        Self.displayTilt(line: line)
      }
      
      let imagingSettingsLines = self[.imagingSettings]
      if imagingSettingsLines.count > 0 {
        guard imagingSettingsLines.count == 3 else {
          fatalError(
            "Invalid number of imaging settings lines: \(imagingSettingsLines.count)")
        }
        
        let labels: [String] = [
          "mode",
          "true resolution major (px)",
          "resolution major (px)",
          "resolution minor (px)",
          "pixel dimension (nm)3",
          
          "major axis",
          "centers[0] - X (nm)",
          "centers[0] - Y (nm)",
          "centers[1] - X (nm)",
          "centers[1] - Y (nm)",
          
          "polynomial peak time (μs)",
          "electronic time lag (μs)",
          "creep setting time (ms)",
          "image time (ms)",
          "feedback time constant (ms)",
          
          "setpoint current (pA)",
        ]
        
        var values: [Float] = []
        for lineID in imagingSettingsLines.indices {
          let line = imagingSettingsLines[lineID]
          let laneCount = (lineID == 3) ? 1 : 5
          
          for laneID in 0..<laneCount {
            let value = line.values[laneID]
            values.append(value)
          }
        }
        
        print()
        print("imaging settings:")
        Self.displayTabulated(labels: labels, values: values)
        print()
      }
      
      for line in self[.creepSettings] {
        let labels: [String] = [
          "creep constants - X (%/decade)2",
          "creep constants - Y (%/decade)2",
        ]
        
        let values: [Float] = [
          line.values[0],
          line.values[1],
        ]
        
        print()
        print("creep settings:")
        Self.displayTabulated(labels: labels, values: values)
        print()
      }
      
      for line in self[.tiltSettings] {
        let labels: [String] = [
          "dz/dx3",
          "dz/dy3",
        ]
        
        let values: [Float] = [
          line.values[0],
          line.values[1]
        ]
        
        print()
        print("tilt settings:")
        Self.displayTabulated(labels: labels, values: values)
        print()
      }
      
      for line in self[.newMode] {
        let modeCode = Int(line.values[0])
        if line.values[1] == 1 {
          print("forced mode change to \(modeCode)")
        }
      }
      
      for line in self[.kilohertzLoop] {
        print("kilohertz loop warning:", terminator: " ")
        
        for laneID in 0..<3 {
          let floatValue = line.values[laneID]
          let uintValue = floatValue.bitPattern >> 8
          print(uintValue, terminator: " ")
        }
        for laneID in 3..<5 {
          let floatValue = line.values[laneID]
          var intValue = Int32(truncatingIfNeeded: floatValue.bitPattern)
          intValue >>= 8
          print(intValue, terminator: " ")
        }
        
        print()
      }
    }
  }
  
  mutating func split(lines: [LineParser.Line]) -> Splitting {
    var splitting = Splitting()
    
    for line in lines {
      let flags = Flags(rawValue: line.flags)
      guard let flags else {
        fatalError("Unexpected flags: \(line.flags)")
      }
      
      switch flags {
      case .history:
        splitting[.history].append(line)
      case .newMode:
        splitting[.newMode].append(line)
        
        let modeCode = Int(line.values[0])
        splitting.newModeCode = modeCode
        splitting[.history] = []
        splitting[.pixel] = []
        
        if modeCode == 8 {
          splitting[.imagingSettings] = pendingImagingSettingsLines
          pendingImagingSettingsLines = []
        }
      case .spectroscopy:
        splitting[.spectroscopy].append(line)
      case .historyDiscard:
        let historyLineCount = splitting[.history].count
        guard historyLineCount == 0 else {
          fatalError("Cannot discard lines once history has started.")
        }
      case .pixel:
        splitting[.pixel].append(line)
      case .imagingSettings:
        pendingImagingSettingsLines.append(line)
      case .creepSettings:
        splitting[.creepSettings].append(line)
      case .kilohertzLoop:
        splitting[.kilohertzLoop].append(line)
      case .tiltSettings:
        splitting[.tiltSettings].append(line)
      case .tilt:
        splitting[.tilt].append(line)
      }
    }
    
    return splitting
  }
}

extension LineParser.Splitting {
  static func displayTabulated(
    labels: [String],
    values: [Float]
  ) {
    guard labels.count == values.count else {
      fatalError("Invalid array lengths.")
    }
    
    func createParsedLabels() -> [(repr: String, decimalPlaces: Int)] {
      var output: [(repr: String, decimalPlaces: Int)] = []
      for rowID in labels.indices {
        let label = labels[rowID]
        
        func createNumberValue() -> Int? {
          guard label.count > 0 else {
            fatalError("No ending character.")
          }
          let lastCharacter = label.last!
          return lastCharacter.wholeNumberValue
        }
        
        if let numberValue = createNumberValue() {
          var truncatedLabel = label
          truncatedLabel.removeLast()
          output.append((truncatedLabel, numberValue))
        } else {
          output.append((label, 1))
        }
      }
      return output
    }
    let parsedLabels = createParsedLabels()
    
    func createParsedValues() -> [String] {
      let maxDecimalPlaces = parsedLabels.map(\.decimalPlaces).max()!
      
      var output: [String] = []
      for rowID in values.indices {
        let parsedLabel = parsedLabels[rowID]
        let value = values[rowID]
        
        let formatString = "%.\(parsedLabel.decimalPlaces)f"
        let repr = String(format: formatString, value)
        
        let paddingSize = maxDecimalPlaces - parsedLabel.decimalPlaces
        let padding = String(repeating: " ", count: paddingSize)
        output.append(repr + padding)
      }
      return output
    }
    let parsedValues = createParsedValues()
    
    func createColumnWidths() -> SIMD2<Int> {
      var output: SIMD2<Int> = .zero
      for rowID in parsedLabels.indices {
        let parsedLabel = parsedLabels[rowID]
        let parsedValue = parsedValues[rowID]
        
        output[0] = max(output[0], parsedLabel.repr.count)
        output[1] = max(output[1], parsedValue.count)
      }
      return output
    }
    let columnWidths = createColumnWidths()
    
    for rowID in parsedLabels.indices {
      let parsedLabel = parsedLabels[rowID]
      let parsedValue = parsedValues[rowID]
      
      let labelPaddingSize = columnWidths[0] - parsedLabel.repr.count
      let numberPaddingSize = columnWidths[1] - parsedValue.count
      
      func createString() -> String {
        var output = ""
        output += parsedLabel.repr
        output += String(repeating: " ", count: labelPaddingSize)
        output += " | "
        output += String(repeating: " ", count: numberPaddingSize)
        output += parsedValue
        return output
      }
      print(createString())
    }
  }
  
  static func displayTilt(line: LineParser.Line) {
    let avg = SIMD2<Float>(line.values[0], line.values[1])
    let stddev = SIMD2<Float>(line.values[2], line.values[3])
    guard let n = Int(exactly: line.values[4]) else {
      fatalError("Malformatted sample count.")
    }
    
    // Report a 99% confidence interval.
    let interval = 2.576 * stddev / Float(n).squareRoot()
    
    var output: String = ""
    output += "tilt | "
    
    func formatAverage(_ x: Float) -> String {
      var output = String(format: "%.3f", x)
      if x >= 0 {
        output = " " + output
      }
      return output
    }
    output += formatAverage(avg[0])
    output += ", "
    output += formatAverage(avg[1])
    output += " | "
    
    func formatUncertainty(_ x: Float) -> String {
      var output = String(format: "%.3f", x)
      output += "±"
      return output
    }
    output += formatUncertainty(interval[0])
    output += ", "
    output += formatUncertainty(interval[1])
    output += " | "
    
    output += "\(n) samples"
    
    print(output)
  }
}
