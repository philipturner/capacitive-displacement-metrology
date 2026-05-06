struct Stream {
  var title: String
  var data: [Float] = []
  
  static func checkStartAndEnd(_ entries: [Entry]) {
    guard case .start = entries[0].id,
          case .end = entries.last!.id else {
      fatalError("Malformatted entries.")
    }
  }
  
  static func createStreams(_ entries: [Entry]) -> [Stream] {
    Self.checkStartAndEnd(entries)
    
    var streams: [Stream] = []
    do {
      let startEntry = entries[0]
      for title in startEntry.values {
        let stream = Stream(title: title)
        streams.append(stream)
      }
    }
    
    var dataEntries = entries
    dataEntries.removeFirst()
    dataEntries.removeLast()
    
    for i in dataEntries.indices {
      let entry = dataEntries[i]
      guard case .number(let entryID) = entry.id else {
        fatalError("Malformatted entry.")
      }
      guard entryID == i else {
        fatalError("Invalid entry ID.")
      }
      guard entry.values.count == streams.count else {
        fatalError("Incorrect number of values.")
      }
      
      for j in entry.values.indices {
        let valueString = entry.values[j]
        guard let value = Float(valueString) else {
          fatalError("Could not decode value.")
        }
        streams[j].data.append(value)
      }
    }
    
    return streams
  }
}
