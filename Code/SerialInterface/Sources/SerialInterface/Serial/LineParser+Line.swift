import func Foundation.atan2

extension LineParser {
  struct Line {
    var flags: UInt8
    var id: UInt64
    var values: SIMD8<Float>
    
    static let messageLength: Int = 28
    static let messageStartCode: UInt8 = Character(">").asciiValue!
    
    init() {
      self.flags = .zero
      self.id = .zero
      self.values = .zero
    }
    
    init(decoding buffer: UnsafePointer<UInt8>) {
      guard buffer[0] == Line.messageStartCode else {
        fatalError("Invalid message.")
      }
      
      var bitPatterns: [UInt64]
      do {
        flags = UInt8(try Self.base64Decode(buffer + 1, encodedLength: 1))
        id = try Self.base64Decode(buffer + 2, encodedLength: 6)
        
        bitPatterns = [
          try Self.base64Decode(buffer + 8, encodedLength: 4),
          try Self.base64Decode(buffer + 12, encodedLength: 4),
          try Self.base64Decode(buffer + 16, encodedLength: 4),
          try Self.base64Decode(buffer + 20, encodedLength: 4),
          try Self.base64Decode(buffer + 24, encodedLength: 4),
        ]
      } catch {
        let string = Line.display(buffer)
        fatalError("Failed to decode. Contents of buffer: \(string)")
      }
      
      values = .zero
      for laneID in 0..<5 {
        var bitPattern = UInt32(bitPatterns[laneID])
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
    ) throws -> UInt64 {
      var value: UInt64 = .zero
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
        
        let leftShiftAmount = UInt64(6 * i)
        value |= UInt64(sixBits) << leftShiftAmount
      }
      return value
    }
    
    static func display(
      _ buffer: UnsafePointer<UInt8>,
      length: Int = Line.messageLength
    ) -> String {
      var string: String = ""
      for i in 0..<Self.messageLength {
        let code = buffer[i]
        let character = Character(Unicode.Scalar(code))
        string.append(character)
      }
      return string
    }
  }
}
