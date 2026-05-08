struct Entry {
  var id: UInt32
  var values: [Float]
  
  init(decoding pointer: UnsafeBufferPointer<UInt8>) {
    guard pointer.count % 8 == 0 else {
      fatalError("String had invalid length.")
    }
    guard pointer.count == 40 else {
      fatalError("Failed second check for invalid length.")
    }
    
    var hexDigits: [UInt8] = []
    let zeroCode = Character("a").asciiValue!
    for charID in pointer.indices {
      let character = pointer[charID]
      let hexDigit = UInt8(truncatingIfNeeded: character) &- zeroCode
      hexDigits.append(hexDigit)
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
