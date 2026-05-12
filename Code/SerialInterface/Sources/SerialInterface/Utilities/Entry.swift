struct Entry {
  var id: Int
  var values: SIMD4<Float>
  
  static let messageLength: Int = 23
  static let messageStartCode: UInt8 = Character(">").asciiValue!
  
  init(id: Int, values: SIMD4<Float>) {
    self.id = id
    self.values = values
  }
  
  init(decoding buffer: UnsafePointer<UInt8>) {
    guard buffer[0] == Entry.messageStartCode else {
      fatalError("Invalid message.")
    }
    
    var numbers: [UInt32]
    do {
      numbers = [
        try Self.base64Decode(buffer + 1, encodedLength: 6),
        try Self.base64Decode(buffer + 7, encodedLength: 4),
        try Self.base64Decode(buffer + 11, encodedLength: 4),
        try Self.base64Decode(buffer + 15, encodedLength: 4),
        try Self.base64Decode(buffer + 19, encodedLength: 4),
      ]
    } catch {
      let string = Entry.display(buffer)
      fatalError("Failed to decode. Contents of buffer: \(string)")
    }
    
    self.id = Int(numbers[0])
    self.values = .zero
    
    for laneID in 0..<4 {
      var bitPattern = numbers[1 + laneID]
      bitPattern <<= 8
      let floatValue = Float(bitPattern: bitPattern)
      values[laneID] = floatValue
    }
  }
  
  private static let codeUpperA: UInt8 = Character("A").asciiValue!
  private static let codeLowerA: UInt8 = Character("a").asciiValue!
  private static let codeZero: UInt8 = Character("0").asciiValue!
  private static let codePlus: UInt8 = Character("+").asciiValue!
  private static let codeForwardSlash: UInt8 = Character("/").asciiValue!
  
  struct Base64Error: Error { }
  
  static func base64Decode(
    _ buffer: UnsafePointer<UInt8>,
    encodedLength: Int
  ) throws -> UInt32 {
    var value: UInt32 = .zero
    for i in 0..<encodedLength {
      let character = buffer[i]
      
      var sixBits: UInt8
      if character >= codeUpperA,
         character < codeUpperA + 26 {
        sixBits = character - codeUpperA
        
      } else if character >= codeLowerA,
                character < codeLowerA + 26 {
        sixBits = (character - codeLowerA) + 26
        
      } else if character >= codeZero,
                character < codeZero + 10 {
        sixBits = (character - codeZero) + 52
        
      } else if character == codePlus {
        sixBits = 62
      } else if character == codeForwardSlash {
        sixBits = 63
      } else {
        throw Base64Error()
      }
      
      let leftShiftAmount = UInt32(6 * i)
      value |= UInt32(sixBits) << leftShiftAmount
    }
    return value
  }
  
  static func display(
    _ buffer: UnsafePointer<UInt8>,
    length: Int = Entry.messageLength
  ) -> String {
    var string: String = ""
    for i in 0..<23 {
      let code = buffer[i]
      let character = Character(Unicode.Scalar(code))
      string.append(character)
    }
    return string
  }
}

extension Entry {
  struct StartCodeCorruptionError: Error {
    var description: String
    var uncorruptedData: [UInt8]
  }
  
  nonisolated(unsafe)
  static var previousPendingBytes: [UInt8] = []
  
  static func decodeEntries(data: [UInt8]) throws -> [Entry] {
    let dataArray = previousPendingBytes + data
    
    func findFirstIndex() -> Int? {
      for i in dataArray.indices {
        let code = dataArray[i]
        if code == Entry.messageStartCode {
          return i
        }
      }
      return nil
    }
    if previousPendingBytes.count > 0 {
      let firstIndex = findFirstIndex()
      guard let firstIndex, firstIndex == 0 else {
        fatalError("This should never happen.")
      }
    }
    previousPendingBytes = []
    
    var entries: [Entry] = []
    if let firstIndex = findFirstIndex() {
      var cursor = firstIndex
      while true {
        let nextCursor = cursor + Entry.messageLength
        guard nextCursor < dataArray.count else {
          let partialMessage = Array(dataArray[cursor...])
          previousPendingBytes = partialMessage
          break
        }
        
        let currentMessageStart = dataArray[cursor]
        let nextMessageStart = dataArray[nextCursor]
        guard currentMessageStart == Entry.messageStartCode,
              nextMessageStart == Entry.messageStartCode else {
          try dataArray.withUnsafeBufferPointer { bufferPointer in
            let buffer = bufferPointer.baseAddress!
            let string1 = Entry.display(buffer + cursor)
            
            var message2Length = dataArray.count - nextCursor
            message2Length = min(message2Length, Entry.messageLength)
            let string2 = Entry.display(
              buffer + nextCursor,
              length: message2Length)
            
            let description = """
              Unexpected start codes for two consecutive messages.
              message 1: \(string1)
              message 2: \(string2)
              cursor 1: \(cursor)
              cursor 2: \(nextCursor)
              array length: \(dataArray.count)
              """
            let uncorruptedData = Array(dataArray[nextCursor...])
            
            throw StartCodeCorruptionError(
              description: description,
              uncorruptedData: uncorruptedData)
          }
          fatalError("Execution should not reach this point.")
        }
        
        dataArray.withUnsafeBufferPointer { bufferPointer in
          let buffer = bufferPointer.baseAddress!
          let entry = Entry(decoding: buffer + cursor)
          entries.append(entry)
        }
        cursor = nextCursor
      }
    }
    return entries
  }
}
