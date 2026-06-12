struct Flags {
  struct LineSplitting {
    var newMode: Int?
    var history: [LineParser.Line] = []
    var spectroscopy: [LineParser.Line] = []
    var pixel: [LineParser.Line] = []
    var imagingSettings: [LineParser.Line] = []
  }
  
  static func split(lines: [LineParser.Line]) -> LineSplitting {
    var output = LineSplitting()
    for line in lines {
      switch line.flags {
      case 0:
        output.history.append(line)
      case 1:
        output.newMode = Int(line.values[0])
        output.history = []
        output.pixel = []
      case 2:
        output.spectroscopy.append(line)
      case 3:
        guard output.history.count == 0 else {
          fatalError("Cannot discard lines once history has started.")
        }
      case 4:
        output.pixel.append(line)
      case 5:
        output.imagingSettings.append(line)
      default:
        fatalError("Unexpected flags: \(line.flags)")
      }
    }
    return output
  }
}
