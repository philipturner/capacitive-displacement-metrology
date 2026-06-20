extension LineParser {
  struct Splitting {
    var newModeCode: Int?
    var data: [[Line]]
    
    init() {
      let element = [Line]()
      data = Array(repeating: element, count: 100)
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
  }
  
  mutating func split(lines: [LineParser.Line]) -> Splitting {
    var splitting = Splitting()
    
    for line in lines {
      let flags = Flags(rawValue: line.flags)
      guard let flags else {
        fatalError("Unexpected flags: \(line.flags)")
      }
      
      switch flags {
      case .modeChange:
        splitting[.modeChange].append(line)
        
        let modeCode = Int(line.values[0])
        splitting.newModeCode = modeCode
        splitting[.history] = []
        splitting[.imaging] = []
        
        if modeCode == 8 {
          splitting[.imagingSettings] = pendingImagingSettingsLines
          pendingImagingSettingsLines = []
        }
      case .kilohertzLoopWarning:
        splitting[.kilohertzLoopWarning].append(line)
      case .invalidCommand:
        splitting[.invalidCommand].append(line)
        
      case .history:
        splitting[.history].append(line)
      case .historyDiscard:
        let historyLineCount = splitting[.history].count
        guard historyLineCount == 0 else {
          fatalError("Cannot discard lines once history has started.")
        }
      case .spectroscopy:
        splitting[.spectroscopy].append(line)
      case .imaging:
        splitting[.imaging].append(line)
      case .imagingSettings:
        pendingImagingSettingsLines.append(line)
      case .creepSettings:
        splitting[.creepSettings].append(line)
      case .tiltCalculation:
        splitting[.tiltCalculation].append(line)
      case .tiltSettings:
        splitting[.tiltSettings].append(line)
      }
    }
    
    return splitting
  }
}
