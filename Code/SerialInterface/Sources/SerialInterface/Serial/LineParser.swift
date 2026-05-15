import Foundation
import SwiftSerial

struct LineParser {
  var previousPendingBytes: [UInt8]
  var totalLineCount: Int
  var previousLineID: Int?
  
  init() {
    self.previousPendingBytes = []
    self.totalLineCount = 0
    self.previousLineID = nil
  }
  
  static func getValidBytes(port: SerialPort) -> [UInt8] {
    let data = Application.queue.sync {
      Watchdog.notify(threadID: 1, code: 3)
      let output = try! port.readBytesBlocking(
        count: 500_000, timeout: 0.001)
      Watchdog.notify(threadID: 1, code: 4)
      return output
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
    var uncorruptedData: [UInt8]
  }
  
  mutating func decodeLines(data: [UInt8]) throws -> [Line] {
    let dataArray = previousPendingBytes + data
    
    func findFirstIndex() -> Int? {
      for i in dataArray.indices {
        let code = dataArray[i]
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
        guard nextCursor < dataArray.count else {
          let partialMessage = Array(dataArray[cursor...])
          previousPendingBytes = partialMessage
          break
        }
        
        let currentMessageStart = dataArray[cursor]
        let nextMessageStart = dataArray[nextCursor]
        guard currentMessageStart == Line.messageStartCode,
              nextMessageStart == Line.messageStartCode else {
          try dataArray.withUnsafeBufferPointer { bufferPointer in
            let buffer = bufferPointer.baseAddress!
            let string1 = Line.display(buffer + cursor)
            
            var message2Length = dataArray.count - nextCursor
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
              array length: \(dataArray.count)
              """
            let uncorruptedData = Array(dataArray[nextCursor...])
            
            throw StartCodeCorruptionError(
              errorDescription: description,
              uncorruptedData: uncorruptedData)
          }
          fatalError("Execution should not reach this point.")
        }
        
        dataArray.withUnsafeBufferPointer { bufferPointer in
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
  
  mutating func finishExtraction(lines: [Line]) throws {
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
