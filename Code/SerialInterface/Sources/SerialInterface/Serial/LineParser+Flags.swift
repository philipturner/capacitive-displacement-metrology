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
}
