import Foundation
import SwiftSerial

struct LineParser {
  var loopIterationID: Int
  var totalLineCount: Int
  var previousEntryID: Int?
  
  init() {
    self.loopIterationID = 0
    self.totalLineCount = 0
    self.previousEntryID = nil
  }
  
  mutating func startExtraction(port: SerialPort) -> [Entry] {
    let data = Application.queue.sync {
      Watchdog.notify(threadID: 1, code: 3)
      let output = try! port.readBytesBlocking(
        count: 1_000_000, timeout: 0.001)
      Watchdog.notify(threadID: 1, code: 4)
      return output
    }
    let validBytes = Self.validBytes(data: data)
    if validBytes.count == 0 {
      return []
    }
    
    // Create the entries while handling a one-time expected error that
    // corrupts the position of start codes.
    defer {
      loopIterationID += 1
    }
    func createEntries() -> [Entry] {
      do {
        let entries = try Entry.decodeEntries(data: validBytes)
        return entries
      } catch let error as Entry.StartCodeCorruptionError {
        print(error.description)
        
        if loopIterationID == 0 {
          let data = error.uncorruptedData
          let entries = try! Entry.decodeEntries(data: data)
          return entries
        } else {
          fatalError("This should not happen on later loop iterations.")
        }
      } catch {
        fatalError("Unexpected error type.")
      }
    }
    let entries = createEntries()
    
    // Handle a case where no start codes are detected, and the above code
    // gracefully generates no entries.
    if totalLineCount == 0,
       entries.count == 0,
       validBytes.count > 0 {
      // This happens when Teensy is reporting an error message.
      let string = String(decoding: validBytes, as: UTF8.self)
      print("Teensy is responding: \(string)")
    }
    
    return entries
  }
  
  private static func validBytes(data: Data) -> [UInt8] {
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
  struct NonContiguousError: Error {
    var description: String
    var uncorruptedEntries: [Entry]
  }
  
  init(recoveringFrom error: NonContiguousError) {
    self.loopIterationID = 1
    self.totalLineCount = 0
    self.previousEntryID = nil
    
    do {
      try finishExtraction(entries: error.uncorruptedEntries)
    } catch let secondError as LineParser.NonContiguousError {
      fatalError("""
        Failed to recover from initial error.
        \(secondError.description)
        """)
    } catch {
      fatalError("Unexpected error type.")
    }
  }
  
  mutating func finishExtraction(entries: [Entry]) throws {
    // Check that the entries have contiguous IDs.
    if entries.count > 0 {
      if let previousEntryID {
        let firstEntryID = entries[0].id
        guard firstEntryID == previousEntryID + 1 else {
          let description = """
            Skipped entries: \(previousEntryID) -> \(firstEntryID)
            Error happened between serial port accesses.
            """
          let uncorruptedEntries = Array(entries[0...])
          
          throw NonContiguousError(
            description: description,
            uncorruptedEntries: uncorruptedEntries)
        }
      }
      
      for i in 1..<entries.count {
        let firstEntryID = entries[i - 1].id
        let secondEntryID = entries[i].id
        guard secondEntryID == firstEntryID + 1 else {
          let description = """
            Skipped entries: \(firstEntryID) -> \(secondEntryID)
            Error happened contiguously to one serial port access.
            """
          let uncorruptedEntries = Array(entries[i...])
          
          throw NonContiguousError(
            description: description,
            uncorruptedEntries: uncorruptedEntries)
        }
      }
      previousEntryID = entries.last!.id
    }
    
    // Update the total line count.
    totalLineCount += entries.count
  }
}
