struct Entry {
  enum ID {
    case start
    case end
    case number(Int)
  }
  var id: ID
  var values: [String]
  
  init?(decoding string: String) {
    let hasStart = (string.first! == ">")
    let hasEnd = (string.last! == "<")
    switch (hasStart, hasEnd) {
    case (true, true):
      break
    case (false, false):
      return nil
    default:
      fatalError("Malformatted string: \(string)")
    }
    
    var shortenedString = string
    shortenedString.removeFirst()
    shortenedString.removeLast()
    
    let substrings = shortenedString
      .split(separator: ",", omittingEmptySubsequences: true)
      .map(String.init)
    guard substrings.count > 0 else {
      fatalError("There were no substrings.")
    }
    
    self.id = Entry.decodeID(substrings[0])
    self.values = Array(substrings[1...])
  }
  
  static func decodeID(_ string: String) -> ID {
    guard string.starts(with: "id:") else {
      fatalError("ID was malformatted.")
    }
    
    var shortenedString = string
    shortenedString.removeFirst(3)
    
    if shortenedString == "start" {
      return ID.start
    } else if shortenedString == "end" {
      return ID.end
    }
    
    if let integerValue = Int(shortenedString) {
      return ID.number(integerValue)
    }
    
    fatalError("No matching ID type.")
  }
}
