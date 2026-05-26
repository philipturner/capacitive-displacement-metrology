import Foundation
import SwiftSerial

struct LineParser {
  var previousPendingBytes: [UInt8] = []
  var totalLineCount: Int = .zero
  var previousLineID: Int?
  
  static func getValidBytes(port: SerialPort) -> [UInt8] {
    let data = Application.queue.sync {
      return try! port.readBytesBlocking(
        count: 500_000, timeout: 0.001)
    }
    
    var output: [UInt8] = []
    for byte in data {
      // Terminate the data at the first zero code.
      if byte == 0 {
        break
      }
      output.append(byte)
    }
    return output
  }
}

extension LineParser {
  struct StartCodeCorruptionError: LocalizedError {
    var errorDescription: String?
    var uncorruptedBytes: [UInt8]
  }
  
  mutating func decode(bytes inputBytes: [UInt8]) throws -> [Line] {
    let bytes = previousPendingBytes + inputBytes
    
    func findFirstIndex() -> Int? {
      for i in bytes.indices {
        let code = bytes[i]
        if code == Line.messageStartCode {
          return i
        }
      }
      return nil
    }
    if previousPendingBytes.count > 0 {
      let firstIndex = findFirstIndex()
      guard let firstIndex, firstIndex == 0 else {
        fatalError("No subsequent lines when pending bytes existed.")
      }
    }
    
    var lines: [Line] = []
    if let firstIndex = findFirstIndex() {
      previousPendingBytes = []
      
      var cursor = firstIndex
      while true {
        let nextCursor = cursor + Line.messageLength
        guard nextCursor < bytes.count else {
          let partialMessage = Array(bytes[cursor...])
          previousPendingBytes = partialMessage
          break
        }
        
        let currentMessageStart = bytes[cursor]
        let nextMessageStart = bytes[nextCursor]
        guard currentMessageStart == Line.messageStartCode,
              nextMessageStart == Line.messageStartCode else {
          try bytes.withUnsafeBufferPointer { bufferPointer in
            let buffer = bufferPointer.baseAddress!
            let string1 = Line.display(buffer + cursor)
            
            var message2Length = bytes.count - nextCursor
            message2Length = min(message2Length, Line.messageLength)
            let string2 = Line.display(
              buffer + nextCursor,
              length: message2Length)
            
            let description = """
              Unexpected start codes for two consecutive messages.
              message 1: \(string1)
              message 2: \(string2)
              cursor 1: \(cursor)
              cursor 2: \(nextCursor)
              array length: \(bytes.count)
              """
            let uncorruptedBytes = Array(bytes[nextCursor...])
            
            throw StartCodeCorruptionError(
              errorDescription: description,
              uncorruptedBytes: uncorruptedBytes)
          }
          fatalError("Execution should not reach this point.")
        }
        
        bytes.withUnsafeBufferPointer { bufferPointer in
          let buffer = bufferPointer.baseAddress!
          let line = Line(decoding: buffer + cursor)
          lines.append(line)
        }
        cursor = nextCursor
      }
    }
    return lines
  }
}

extension LineParser {
  struct NonContiguousError: LocalizedError {
    var errorDescription: String?
    var uncorruptedLines: [Line]
  }
  
  mutating func count(lines: [Line]) throws {
    // Check that the lines have contiguous IDs.
    if lines.count > 0 {
      if let previousLineID {
        let firstLineID = lines[0].id
        guard firstLineID == previousLineID + 1 else {
          let description = """
            Skipped lines: \(previousLineID) -> \(firstLineID)
            Error happened between serial port accesses.
            """
          let uncorruptedLines = Array(lines[0...])
          
          throw NonContiguousError(
            errorDescription: description,
            uncorruptedLines: uncorruptedLines)
        }
      }
      
      for i in 1..<lines.count {
        let firstLineID = lines[i - 1].id
        let secondLineID = lines[i].id
        guard secondLineID == firstLineID + 1 else {
          let description = """
            Skipped lines: \(firstLineID) -> \(secondLineID)
            Error happened contiguously to one serial port access.
            """
          let uncorruptedLines = Array(lines[i...])
          
          throw NonContiguousError(
            errorDescription: description,
            uncorruptedLines: uncorruptedLines)
        }
      }
      previousLineID = lines.last!.id
    }
    
    // Update the total line count.
    totalLineCount += lines.count
  }
}
