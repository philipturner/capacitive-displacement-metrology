struct Entry {
  var id: UInt32
  var values: [Float]
  
  init(decoding string: String) {
    let hasStart = (string.first! == ">")
    let hasEnd = (string.last! == "<")
    guard hasStart, hasEnd else {
      fatalError("Malformatted entry: \(string)")
    }
    
    var shortenedString = string
    shortenedString.removeFirst()
    shortenedString.removeLast()
    guard shortenedString.count % 8 == 0 else {
      fatalError("String was not hex encoded 32-bit values.")
    }
    
    var hexDigits: [UInt8] = []
    let zeroCode = Character("a").asciiValue!
    for character in shortenedString.utf8CString {
      let hexDigit = UInt8(truncatingIfNeeded: character) &- zeroCode
      hexDigits.append(hexDigit)
    }
    guard hexDigits.count == shortenedString.count else {
      fatalError("Malformatted string.")
    }
    
    let numberCount = hexDigits.count / 8
    var bitPatterns: [UInt32] = []
    for numberID in 0..<numberCount {
      var bitPattern: UInt32 = .zero
      for charID in 0..<8 {
        let rightShiftAmount = 4 * charID
        let indexInDigits = 8 * numberID + charID
        
        let fourBits = UInt32(hexDigits[indexInDigits])
        bitPattern |= fourBits << rightShiftAmount
      }
      bitPatterns.append(bitPattern)
    }
    
    guard numberCount >= 1 else {
      fatalError("Not enough numbers to establish an ID.")
    }
    self.id = bitPatterns[0]
    self.values = []
    
    for bitPattern in bitPatterns[1...] {
      let floatValue = Float(bitPattern: bitPattern)
      self.values.append(floatValue)
    }
  }
}
