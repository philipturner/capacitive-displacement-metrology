struct Spectroscopy {
  static func removeResultLines(
    _ input: inout [LineParser.Line]
  ) -> [LineParser.Line] {
    var outputNormal: [LineParser.Line] = []
    var outputResult: [LineParser.Line] = []
    for line in input {
      if line.flags == 0 || line.flags == 1 {
        outputNormal.append(line)
      } else if line.flags == 2 {
        outputResult.append(line)
      } else {
        fatalError("Flags not handled: \(line.flags)")
      }
    }
    
    input = outputNormal
    return outputResult
  }
  
  static func displayResultLines(_ lines: [LineParser.Line]) {
    for line in lines {
      for laneID in 0..<5 {
        let value = line.values[laneID]
        print(value, terminator: ", ")
      }
      print()
    }
  }
}
