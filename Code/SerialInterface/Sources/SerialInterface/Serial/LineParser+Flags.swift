extension LineParser {
  enum Flags: UInt8, CaseIterable {
    case history = 0
    case newMode = 1
    case spectroscopy = 2
    case discard = 3
    case pixel = 4
    case imagingSettings = 5
    case creepSettings = 6
  }
  
  struct Splitting {
    var newMode: Int?
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
        for laneID in 0..<5 {
          let value = line.values[laneID]
          print(value, terminator: ", ")
        }
        print()
      }
      
      let imagingSettingsLines = self[.imagingSettings]
      if imagingSettingsLines.count > 0 {
        guard imagingSettingsLines.count == 3 else {
          fatalError(
            "Invalid number of imaging settings lines: \(imagingSettingsLines.count)")
        }
        
        let labels: [String] = [
          "mode",
          "resolution major (px)",
          "resolution minor (px)",
          "pixel dimension (nm)",
          "polynomial peak time (μs)",
          
          "dominant axis",
          "centers[0] - X (nm)",
          "centers[0] - Y (nm)",
          "centers[1] - X (nm)",
          "centers[1] - Y (nm)",
          
          "electronic time lag (μs)",
          "creep setting time (μs)",
          "setpoint current (pA)",
        ]
        
        var values: [Float] = []
        for lineID in imagingSettingsLines.indices {
          let line = imagingSettingsLines[lineID]
          let laneCount = (lineID == 2) ? 3 : 5
          
          for laneID in 0..<laneCount {
            let value = line.values[laneID]
            values.append(value)
          }
        }
        
        print()
        print("imaging settings:")
        print()
      }
      
      let creepSettingsLines = self[.creepSettings]
      for line in creepSettingsLines {
        let labels: [String] = [
          "creep constants - X (%/decade)2",
          "creep constants - Y (%/decade)2",
          "drift - X (nm)",
          "drift - Y (nm)",
        ]
        
        let values: [Float] = [
          line.values[0],
          line.values[1],
          line.values[2],
          line.values[3],
        ]
        
        print()
        print("creep settings:")
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
        let modeCode = Int(line.values[0])
        splitting.newMode = modeCode
        splitting[.history] = []
        splitting[.pixel] = []
        
        if modeCode == 8 {
          splitting[.imagingSettings] = pendingImagingSettingsLines
          pendingImagingSettingsLines = []
        }
      case .spectroscopy:
        splitting[.spectroscopy].append(line)
      case .discard:
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
      fatalError("Invalid table.")
    }
    
    var parsedValues: [(repr: String, decimalPlaces: Int)] = []
    for rowID in values.indices {
      func getDecimalPlaces() -> Int {
        let label = labels[rowID]
        guard label.count > 0 else {
          fatalError("No ending character.")
        }
        let lastCharacter = label.last!
        
        if let numberValue = lastCharacter.wholeNumberValue {
          return numberValue
        } else {
          return 1
        }
      }
    }
    
    for character in labels[0] {
      if character.isNumber
    }
  }
}
